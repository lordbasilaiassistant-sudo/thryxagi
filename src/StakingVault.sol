// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title StakingVault - Lock OBSD, earn a share of all platform fees
/// @notice Uses the magnified dividends pattern for O(1) reward claims.
///         Treasury calls distributeRewards() to drip OBSD to all stakers pro-rata.
contract StakingVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable obsd;

    uint256 public totalStaked;

    /// @dev Magnifier for precision in dividend calculations
    uint256 private constant MAGNITUDE = 2 ** 128;

    /// @dev Accumulated rewards per share, magnified by MAGNITUDE
    uint256 private magnifiedRewardsPerShare;

    mapping(address => uint256) public staked;
    mapping(address => int256) private magnifiedRewardCorrections;
    mapping(address => uint256) private withdrawnRewards;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsDistributed(address indexed distributor, uint256 amount);

    constructor(address _obsd) {
        require(_obsd != address(0), "Zero address");
        obsd = IERC20(_obsd);
    }

    /// @notice Stake OBSD into the vault
    /// @param amount Amount of OBSD to stake
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");

        obsd.safeTransferFrom(msg.sender, address(this), amount);

        staked[msg.sender] += amount;
        totalStaked += amount;

        magnifiedRewardCorrections[msg.sender] -= int256(magnifiedRewardsPerShare * amount);

        emit Staked(msg.sender, amount);
    }

    /// @notice Unstake OBSD from the vault
    /// @param amount Amount of OBSD to unstake
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        require(staked[msg.sender] >= amount, "Insufficient stake");

        staked[msg.sender] -= amount;
        totalStaked -= amount;

        magnifiedRewardCorrections[msg.sender] += int256(magnifiedRewardsPerShare * amount);

        obsd.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /// @notice Claim accumulated OBSD rewards
    function claimRewards() external nonReentrant {
        uint256 claimable = _withdrawableRewardsOf(msg.sender);
        require(claimable > 0, "No rewards");

        withdrawnRewards[msg.sender] += claimable;
        obsd.safeTransfer(msg.sender, claimable);

        emit RewardsClaimed(msg.sender, claimable);
    }

    /// @notice Distribute OBSD rewards to all stakers pro-rata
    /// @param amount Amount of OBSD to distribute
    function distributeRewards(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot distribute 0");
        require(totalStaked > 0, "No stakers");

        obsd.safeTransferFrom(msg.sender, address(this), amount);

        magnifiedRewardsPerShare += (amount * MAGNITUDE) / totalStaked;

        emit RewardsDistributed(msg.sender, amount);
    }

    /// @notice View pending (unclaimed) rewards for a user
    function pendingRewards(address user) external view returns (uint256) {
        return _withdrawableRewardsOf(user);
    }

    /// @dev Accumulated rewards for a user (includes already withdrawn)
    function _accumulatedRewardsOf(address user) private view returns (uint256) {
        return uint256(int256(magnifiedRewardsPerShare * staked[user]) + magnifiedRewardCorrections[user]) / MAGNITUDE;
    }

    /// @dev Withdrawable rewards = accumulated - already withdrawn
    function _withdrawableRewardsOf(address user) private view returns (uint256) {
        return _accumulatedRewardsOf(user) - withdrawnRewards[user];
    }
}
