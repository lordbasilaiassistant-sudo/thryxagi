// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAeroRouterMinimal {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function defaultFactory() external view returns (address);
}

/// @title CreatorToken — ERC20 that auto-pays creator & treasury in OBSD
/// @notice 3% fee on every transfer → batch swap to OBSD → 50/50 auto-distribute.
///         Creator gets OBSD. Treasury gets OBSD. No claiming needed — fully automatic.
///
/// Fee flow:  Transfer → 3% fee → accumulate → threshold hit → swap Child→OBSD on Aero
///            → 50% OBSD to creator, 50% OBSD to treasury (instant, same tx)
contract CreatorToken is ERC20 {
    uint256 public constant FEE_BPS = 300; // 3% on all transfers

    address public immutable creator;      // earns 50% of fees in OBSD
    address public immutable treasury;     // earns 50% of fees in OBSD
    address public immutable obsd;
    address public immutable aeroRouter;
    address public immutable aeroFactory;
    uint256 public immutable swapThreshold; // auto-distribute when this much accumulates

    uint256 public pendingFees;
    uint256 public totalOBSDToCreator;     // lifetime OBSD earned by creator
    uint256 public totalOBSDToTreasury;    // lifetime OBSD earned by treasury

    bool private _inSwap;

    // Fee-exempt addresses (factory during seeding)
    mapping(address => bool) public feeExempt;

    event FeesDistributed(uint256 obsdToCreator, uint256 obsdToTreasury);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 supply_,
        address recipient_,
        address creator_,
        address treasury_,
        address obsd_,
        address aeroRouter_,
        address factory_
    ) ERC20(name_, symbol_) {
        creator = creator_;
        treasury = treasury_;
        obsd = obsd_;
        aeroRouter = aeroRouter_;
        aeroFactory = IAeroRouterMinimal(aeroRouter_).defaultFactory();
        swapThreshold = supply_ / 10000; // 0.01% of supply

        // Factory exempt during pool seeding
        feeExempt[factory_] = true;

        // Pre-approve Aero router for fee swaps
        _approve(address(this), aeroRouter_, type(uint256).max);

        _mint(recipient_, supply_);
    }

    function _update(address from, address to, uint256 value) internal override {
        // No fee on: mint, burn, distribution swaps, or exempt addresses
        if (from == address(0) || to == address(0) || _inSwap || feeExempt[from]) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = (value * FEE_BPS) / 10000;
        uint256 send = value - fee;

        // Fee accumulates in this contract
        super._update(from, address(this), fee);
        // Remainder goes to recipient
        super._update(from, to, send);

        pendingFees += fee;

        // Auto-distribute when threshold hit
        if (pendingFees >= swapThreshold) {
            _autoDistribute();
        }
    }

    function _autoDistribute() internal {
        _inSwap = true;

        uint256 amount = pendingFees;
        pendingFees = 0;

        // Swap accumulated child tokens → OBSD via Aerodrome
        IAeroRouterMinimal.Route[] memory routes = new IAeroRouterMinimal.Route[](1);
        routes[0] = IAeroRouterMinimal.Route({
            from: address(this),
            to: obsd,
            stable: false,
            factory: aeroFactory
        });

        try IAeroRouterMinimal(aeroRouter).swapExactTokensForTokens(
            amount, 0, routes, address(this), block.timestamp + 300
        ) returns (uint256[] memory amounts) {
            uint256 obsdReceived = amounts[amounts.length - 1];
            uint256 creatorShare = obsdReceived / 2;
            uint256 treasuryShare = obsdReceived - creatorShare;

            // Auto-send — no claiming needed
            IERC20(obsd).transfer(creator, creatorShare);
            IERC20(obsd).transfer(treasury, treasuryShare);

            totalOBSDToCreator += creatorShare;
            totalOBSDToTreasury += treasuryShare;

            emit FeesDistributed(creatorShare, treasuryShare);
        } catch {
            // Pool has no liquidity yet — hold fees for next attempt
            pendingFees = amount;
        }

        _inSwap = false;
    }

    /// @notice Burn tokens (used by LaunchPad to burn non-pool allocation)
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Anyone can trigger distribution (useful before threshold)
    function distribute() external {
        require(pendingFees > 0, "No fees");
        _autoDistribute();
    }
}
