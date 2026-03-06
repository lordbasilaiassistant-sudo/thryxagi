// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CreatorTokenV2} from "./CreatorTokenV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAeroFactory {
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);
    function createPool(address tokenA, address tokenB, bool stable) external returns (address);
}

interface IAeroLaunchRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function defaultFactory() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

/// @title LaunchPad — Permissionless token factory for the OBSD Creator Economy
/// @notice Deploys CreatorTokens paired with OBSD on Aerodrome. Creators earn OBSD
///         automatically on every swap — no claiming, no gas, no wallet needed.
///
///         How it works for creators:
///         1. Creator submits name, symbol, payout address via frontend
///         2. Platform deploys token + pool (creator pays nothing)
///         3. Every trade auto-distributes OBSD: 50% creator, 50% treasury
///         4. Creator earns OBSD forever on every swap of their token
contract LaunchPad {
    address public immutable obsd;
    address public immutable aeroRouter;
    address public immutable aeroFactory;
    address public immutable treasury;
    address public immutable owner;

    struct Launch {
        address token;
        address pool;
        address creator;
        string name;
        string symbol;
        uint256 supply;
        uint256 obsdSeeded;
        uint256 timestamp;
    }

    Launch[] public launches;
    mapping(address => uint256[]) public creatorLaunches; // creator → launch IDs
    mapping(string => bool) public symbolTaken;

    event TokenLaunched(
        uint256 indexed launchId,
        address indexed token,
        address indexed creator,
        address pool
    );

    constructor(address obsd_, address aeroRouter_, address treasury_) {
        obsd = obsd_;
        aeroRouter = aeroRouter_;
        aeroFactory = IAeroLaunchRouter(aeroRouter_).defaultFactory();
        treasury = treasury_;
        owner = msg.sender;
    }

    /// @notice Launch a new creator token paired with OBSD
    /// @param name_ Token name (e.g., "Degen Ape")
    /// @param symbol_ Token ticker (e.g., "DAPE") — must be unique
    /// @param supply_ Total supply in wei (default: 1e9 * 1e18 = 1 billion)
    /// @param obsdSeed_ OBSD to seed pool (caller must approve this contract)
    /// @param poolPercent_ % of supply for pool (1-100, rest goes to creator)
    /// @param creatorPayout_ Address that receives OBSD earnings
    function launch(
        string calldata name_,
        string calldata symbol_,
        uint256 supply_,
        uint256 obsdSeed_,
        uint256 poolPercent_,
        address creatorPayout_
    ) external returns (address token, address pool) {
        require(msg.sender == owner, "Only owner");
        require(poolPercent_ > 0 && poolPercent_ <= 100, "Bad percent");
        require(obsdSeed_ > 0, "Need OBSD");
        require(creatorPayout_ != address(0), "Need creator address");
        require(!symbolTaken[symbol_], "Symbol taken");

        symbolTaken[symbol_] = true;

        // Deploy CreatorTokenV2 — 1% burn + 1% creator + 1% treasury + progressive sell tax
        token = address(new CreatorTokenV2(
            name_, symbol_, supply_, address(this),
            creatorPayout_, treasury, obsd, aeroRouter, address(this)
        ));

        // Pull OBSD from caller
        IERC20(obsd).transferFrom(msg.sender, address(this), obsdSeed_);

        // Create Aerodrome volatile pool
        pool = IAeroFactory(aeroFactory).getPool(token, obsd, false);
        if (pool == address(0)) {
            pool = IAeroFactory(aeroFactory).createPool(token, obsd, false);
        }

        // Tell the token its pool address (needed for buy/sell detection)
        // Must be called before seeding so the token can track buys correctly
        CreatorTokenV2(token).setPool(pool);

        // Seed liquidity — LP tokens go to treasury (we own the liquidity)
        uint256 tokenForPool = (supply_ * poolPercent_) / 100;
        IERC20(token).approve(aeroRouter, tokenForPool);
        IERC20(obsd).approve(aeroRouter, obsdSeed_);

        IAeroLaunchRouter(aeroRouter).addLiquidity(
            token, obsd, false,
            tokenForPool, obsdSeed_,
            tokenForPool * 95 / 100, obsdSeed_ * 95 / 100,
            treasury,
            block.timestamp + 300
        );

        // Burn remaining tokens — creator earns via OBSD fees, not token dumps
        uint256 remaining = IERC20(token).balanceOf(address(this));
        if (remaining > 0) {
            CreatorTokenV2(token).burn(remaining);
        }

        // Record launch
        uint256 launchId = launches.length;
        launches.push(Launch({
            token: token,
            pool: pool,
            creator: creatorPayout_,
            name: name_,
            symbol: symbol_,
            supply: supply_,
            obsdSeeded: obsdSeed_,
            timestamp: block.timestamp
        }));
        creatorLaunches[creatorPayout_].push(launchId);

        emit TokenLaunched(launchId, token, creatorPayout_, pool);
    }

    /// @notice Total tokens launched
    function totalLaunches() external view returns (uint256) {
        return launches.length;
    }

    /// @notice Get all launch IDs for a creator
    function getCreatorLaunches(address creator_) external view returns (uint256[] memory) {
        return creatorLaunches[creator_];
    }

    /// @notice Recover stuck tokens
    function recover(address _token, uint256 _amount) external {
        require(msg.sender == owner, "Only owner");
        IERC20(_token).transfer(msg.sender, _amount);
    }
}
