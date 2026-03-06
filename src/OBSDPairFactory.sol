// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ChildToken} from "./ChildToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title OBSDPairFactory — Deploy tokens paired with OBSD on Aerodrome
/// @notice Deploys a ChildToken, creates an Aerodrome volatile pool (NewToken/OBSD),
///         and seeds initial liquidity. Every child token drives OBSD demand.
///
/// Revenue model:
///   1. To buy any child token, users need OBSD first → buy through OBSD router → 1% creator fee
///   2. Swaps in the Aero pool generate LP fees → claimable by LP position holder
///   3. More child tokens = more OBSD demand = higher IV for all holders

interface IAerodromeRouter {
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

interface IAerodromeFactory {
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);
    function createPool(address tokenA, address tokenB, bool stable) external returns (address);
}

contract OBSDPairFactory {
    address public immutable obsd;
    address public immutable aeroRouter;
    address public immutable aeroFactory;
    address public immutable owner;

    struct Launch {
        address token;
        address pool;
        string name;
        string symbol;
        uint256 supply;
        uint256 obsdSeeded;
        uint256 timestamp;
    }

    Launch[] public launches;
    mapping(address => uint256) public tokenToLaunchId;

    event TokenLaunched(
        uint256 indexed launchId,
        address indexed token,
        address pool,
        uint256 obsdSeeded
    );

    constructor(address _obsd, address _aeroRouter) {
        obsd = _obsd;
        aeroRouter = _aeroRouter;
        aeroFactory = IAerodromeRouter(_aeroRouter).defaultFactory();
        owner = msg.sender;
    }

    /// @notice Deploy a new token paired with OBSD
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param supply_ Total supply (in wei, e.g. 1e9 * 1e18 for 1 billion)
    /// @param obsdAmount_ How much OBSD to seed in the pool (must be pre-approved)
    /// @param tokenSeedPercent_ What % of supply goes to pool (rest stays with caller). 1-100.
    function launch(
        string calldata name_,
        string calldata symbol_,
        uint256 supply_,
        uint256 obsdAmount_,
        uint256 tokenSeedPercent_
    ) external returns (address token, address pool) {
        require(msg.sender == owner, "Only owner");
        require(tokenSeedPercent_ > 0 && tokenSeedPercent_ <= 100, "Bad percent");
        require(obsdAmount_ > 0, "Need OBSD");

        // Deploy child token — all supply minted to this contract
        token = address(new ChildToken(name_, symbol_, supply_, address(this)));

        // Pull OBSD from caller
        IERC20(obsd).transferFrom(msg.sender, address(this), obsdAmount_);

        // Create Aerodrome volatile pool
        pool = IAerodromeFactory(aeroFactory).getPool(token, obsd, false);
        if (pool == address(0)) {
            pool = IAerodromeFactory(aeroFactory).createPool(token, obsd, false);
        }

        // Seed liquidity
        uint256 tokenForPool = (supply_ * tokenSeedPercent_) / 100;
        _seedPool(token, tokenForPool, obsdAmount_, msg.sender);

        // Send remaining tokens to owner
        uint256 tokenForOwner = supply_ - tokenForPool;
        if (tokenForOwner > 0) {
            IERC20(token).transfer(msg.sender, tokenForOwner);
        }

        // Record launch
        _recordLaunch(token, pool, name_, symbol_, supply_, obsdAmount_);
    }

    function _seedPool(address token, uint256 tokenAmt, uint256 obsdAmt, address lpTo) internal {
        IERC20(token).approve(aeroRouter, tokenAmt);
        IERC20(obsd).approve(aeroRouter, obsdAmt);

        IAerodromeRouter(aeroRouter).addLiquidity(
            token,
            obsd,
            false,
            tokenAmt,
            obsdAmt,
            tokenAmt * 95 / 100,
            obsdAmt * 95 / 100,
            lpTo,
            block.timestamp + 300
        );
    }

    function _recordLaunch(
        address token, address pool,
        string calldata name_, string calldata symbol_,
        uint256 supply_, uint256 obsdAmount_
    ) internal {
        uint256 launchId = launches.length;
        launches.push(Launch({
            token: token,
            pool: pool,
            name: name_,
            symbol: symbol_,
            supply: supply_,
            obsdSeeded: obsdAmount_,
            timestamp: block.timestamp
        }));
        tokenToLaunchId[token] = launchId;

        emit TokenLaunched(launchId, token, pool, obsdAmount_);
    }

    /// @notice How many tokens launched through this factory
    function totalLaunches() external view returns (uint256) {
        return launches.length;
    }

    /// @notice Recover any stuck tokens (safety valve)
    function recover(address _token, uint256 _amount) external {
        require(msg.sender == owner, "Only owner");
        IERC20(_token).transfer(msg.sender, _amount);
    }
}
