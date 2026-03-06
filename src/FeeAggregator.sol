// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAeroPool {
    function claimFees() external returns (uint256 claimed0, uint256 claimed1);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function defaultFactory() external view returns (address);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

/// @title FeeAggregator — Collects LP fees from Aerodrome pools and forwards as OBSD
/// @notice Keeper-callable contract that harvests fees from tracked creator token pools,
///         swaps non-OBSD tokens to OBSD via Aerodrome, and sends to StakingVault.
contract FeeAggregator {
    address public owner;
    address public immutable obsd;
    address public immutable aeroRouter;
    address public immutable aeroFactory;
    address public stakingVault;

    address[] public pools;
    mapping(address => bool) public isTracked;

    event PoolAdded(address indexed pool);
    event PoolRemoved(address indexed pool);
    event FeesHarvested(address indexed pool, uint256 obsdAmount);
    event VaultUpdated(address indexed oldVault, address indexed newVault);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address obsd_, address aeroRouter_, address stakingVault_) {
        require(obsd_ != address(0) && aeroRouter_ != address(0), "Zero address");
        obsd = obsd_;
        aeroRouter = aeroRouter_;
        aeroFactory = IAeroRouter(aeroRouter_).defaultFactory();
        stakingVault = stakingVault_;
        owner = msg.sender;
    }

    /// @notice Add a pool to track for fee harvesting
    function addPool(address pool) external onlyOwner {
        require(pool != address(0), "Zero address");
        require(!isTracked[pool], "Already tracked");
        pools.push(pool);
        isTracked[pool] = true;
        emit PoolAdded(pool);
    }

    /// @notice Remove a pool from tracking
    function removePool(address pool) external onlyOwner {
        require(isTracked[pool], "Not tracked");
        isTracked[pool] = false;

        // Swap with last and pop
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i] == pool) {
                pools[i] = pools[pools.length - 1];
                pools.pop();
                break;
            }
        }
        emit PoolRemoved(pool);
    }

    /// @notice Harvest fees from a single pool, swap to OBSD, send to vault
    /// @dev Callable by anyone (keeper pattern)
    function harvestPool(address pool) public returns (uint256 obsdTotal) {
        require(isTracked[pool], "Not tracked");

        (uint256 claimed0, uint256 claimed1) = IAeroPool(pool).claimFees();

        address token0 = IAeroPool(pool).token0();
        address token1 = IAeroPool(pool).token1();

        // Swap non-OBSD fees to OBSD
        if (claimed0 > 0) {
            obsdTotal += _swapToObsd(token0, claimed0);
        }
        if (claimed1 > 0) {
            obsdTotal += _swapToObsd(token1, claimed1);
        }

        // Forward OBSD to vault
        if (obsdTotal > 0 && stakingVault != address(0)) {
            IERC20(obsd).transfer(stakingVault, obsdTotal);
        }

        emit FeesHarvested(pool, obsdTotal);
    }

    /// @notice Harvest fees from all tracked pools
    /// @dev Callable by anyone (keeper pattern)
    function harvestAll() external returns (uint256 totalObsd) {
        for (uint256 i = 0; i < pools.length; i++) {
            totalObsd += harvestPool(pools[i]);
        }
    }

    /// @notice Get all tracked pools
    function getPools() external view returns (address[] memory) {
        return pools;
    }

    /// @notice Get number of tracked pools
    function poolCount() external view returns (uint256) {
        return pools.length;
    }

    /// @notice Update the staking vault address
    function setStakingVault(address newVault) external onlyOwner {
        emit VaultUpdated(stakingVault, newVault);
        stakingVault = newVault;
    }

    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Rescue tokens accidentally sent to this contract
    function rescue(address token, uint256 amount, address to) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    // --- Internal ---

    function _swapToObsd(address tokenIn, uint256 amountIn) internal returns (uint256 obsdOut) {
        if (tokenIn == obsd) {
            return amountIn; // Already OBSD, no swap needed
        }

        IERC20(tokenIn).approve(aeroRouter, amountIn);

        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({
            from: tokenIn,
            to: obsd,
            stable: false,
            factory: aeroFactory
        });

        uint256[] memory amounts = IAeroRouter(aeroRouter).swapExactTokensForTokens(
            amountIn,
            0, // Accept any amount (keeper can MEV-protect via private mempool)
            routes,
            address(this),
            block.timestamp
        );

        obsdOut = amounts[amounts.length - 1];
    }
}
