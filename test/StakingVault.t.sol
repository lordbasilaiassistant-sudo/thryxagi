// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {StakingVault} from "../src/StakingVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockOBSD is ERC20 {
    constructor() ERC20("Obsidian", "OBSD") {
        _mint(msg.sender, 1_000_000_000e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StakingVaultTest is Test {
    StakingVault vault;
    MockOBSD obsd;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address treasury = makeAddr("treasury");

    function setUp() public {
        obsd = new MockOBSD();
        vault = new StakingVault(address(obsd));

        // Fund users
        obsd.transfer(alice, 100_000e18);
        obsd.transfer(bob, 100_000e18);
        obsd.transfer(treasury, 500_000e18);
    }

    function testStake() public {
        vm.startPrank(alice);
        obsd.approve(address(vault), 10_000e18);
        vault.stake(10_000e18);
        vm.stopPrank();

        assertEq(vault.staked(alice), 10_000e18);
        assertEq(vault.totalStaked(), 10_000e18);
        assertEq(obsd.balanceOf(address(vault)), 10_000e18);
    }

    function testUnstake() public {
        vm.startPrank(alice);
        obsd.approve(address(vault), 10_000e18);
        vault.stake(10_000e18);
        vault.unstake(5_000e18);
        vm.stopPrank();

        assertEq(vault.staked(alice), 5_000e18);
        assertEq(vault.totalStaked(), 5_000e18);
        assertEq(obsd.balanceOf(alice), 95_000e18); // 100k - 10k + 5k
    }

    function testCannotUnstakeMoreThanStaked() public {
        vm.startPrank(alice);
        obsd.approve(address(vault), 10_000e18);
        vault.stake(10_000e18);
        vm.expectRevert("Insufficient stake");
        vault.unstake(10_001e18);
        vm.stopPrank();
    }

    function testCannotStakeZero() public {
        vm.startPrank(alice);
        obsd.approve(address(vault), 10_000e18);
        vm.expectRevert("Cannot stake 0");
        vault.stake(0);
        vm.stopPrank();
    }

    function testDistributeAndClaim() public {
        // Alice stakes 10k
        vm.startPrank(alice);
        obsd.approve(address(vault), 10_000e18);
        vault.stake(10_000e18);
        vm.stopPrank();

        // Treasury distributes 1k rewards
        vm.startPrank(treasury);
        obsd.approve(address(vault), 1_000e18);
        vault.distributeRewards(1_000e18);
        vm.stopPrank();

        // Alice should have ~1k pending (1 wei rounding dust is normal)
        assertApproxEqAbs(vault.pendingRewards(alice), 1_000e18, 1);

        // Alice claims
        vm.prank(alice);
        vault.claimRewards();

        assertEq(vault.pendingRewards(alice), 0);
        assertApproxEqAbs(obsd.balanceOf(alice), 91_000e18, 1); // 100k - 10k + 1k
    }

    function testMultipleStakersProRata() public {
        // Alice stakes 30k, Bob stakes 10k (3:1 ratio)
        vm.startPrank(alice);
        obsd.approve(address(vault), 30_000e18);
        vault.stake(30_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        obsd.approve(address(vault), 10_000e18);
        vault.stake(10_000e18);
        vm.stopPrank();

        // Distribute 4k rewards
        vm.startPrank(treasury);
        obsd.approve(address(vault), 4_000e18);
        vault.distributeRewards(4_000e18);
        vm.stopPrank();

        // Alice gets ~3k, Bob gets ~1k (1 wei rounding dust)
        assertApproxEqAbs(vault.pendingRewards(alice), 3_000e18, 1);
        assertApproxEqAbs(vault.pendingRewards(bob), 1_000e18, 1);

        // Both claim
        vm.prank(alice);
        vault.claimRewards();
        vm.prank(bob);
        vault.claimRewards();

        assertApproxEqAbs(obsd.balanceOf(alice), 73_000e18, 1); // 100k - 30k + 3k
        assertApproxEqAbs(obsd.balanceOf(bob), 91_000e18, 1); // 100k - 10k + 1k
    }

    function testStakeAfterDistribution() public {
        // Alice stakes first
        vm.startPrank(alice);
        obsd.approve(address(vault), 10_000e18);
        vault.stake(10_000e18);
        vm.stopPrank();

        // Distribute 2k
        vm.startPrank(treasury);
        obsd.approve(address(vault), 2_000e18);
        vault.distributeRewards(2_000e18);
        vm.stopPrank();

        // Bob stakes AFTER distribution — should NOT get past rewards
        vm.startPrank(bob);
        obsd.approve(address(vault), 10_000e18);
        vault.stake(10_000e18);
        vm.stopPrank();

        assertApproxEqAbs(vault.pendingRewards(alice), 2_000e18, 1);
        assertEq(vault.pendingRewards(bob), 0);

        // Distribute another 2k — now split 50/50
        vm.startPrank(treasury);
        obsd.approve(address(vault), 2_000e18);
        vault.distributeRewards(2_000e18);
        vm.stopPrank();

        assertApproxEqAbs(vault.pendingRewards(alice), 3_000e18, 1); // 2k + 1k
        assertApproxEqAbs(vault.pendingRewards(bob), 1_000e18, 1);
    }

    function testUnstakePreservesRewards() public {
        // Alice stakes 10k
        vm.startPrank(alice);
        obsd.approve(address(vault), 10_000e18);
        vault.stake(10_000e18);
        vm.stopPrank();

        // Distribute 2k
        vm.startPrank(treasury);
        obsd.approve(address(vault), 2_000e18);
        vault.distributeRewards(2_000e18);
        vm.stopPrank();

        // Alice unstakes 5k — rewards should still be claimable
        vm.prank(alice);
        vault.unstake(5_000e18);

        assertApproxEqAbs(vault.pendingRewards(alice), 2_000e18, 1);

        // Alice claims
        vm.prank(alice);
        vault.claimRewards();

        assertApproxEqAbs(obsd.balanceOf(alice), 97_000e18, 1); // 100k - 10k + 5k + 2k
    }

    function testCannotDistributeWithNoStakers() public {
        vm.startPrank(treasury);
        obsd.approve(address(vault), 1_000e18);
        vm.expectRevert("No stakers");
        vault.distributeRewards(1_000e18);
        vm.stopPrank();
    }

    function testCannotClaimZero() public {
        vm.prank(alice);
        vm.expectRevert("No rewards");
        vault.claimRewards();
    }

    function testMultipleDistributionsAndClaims() public {
        vm.startPrank(alice);
        obsd.approve(address(vault), 10_000e18);
        vault.stake(10_000e18);
        vm.stopPrank();

        // 3 rounds of distribution
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(treasury);
            obsd.approve(address(vault), 1_000e18);
            vault.distributeRewards(1_000e18);
            vm.stopPrank();
        }

        assertApproxEqAbs(vault.pendingRewards(alice), 3_000e18, 1);

        vm.prank(alice);
        vault.claimRewards();

        // Another distribution
        vm.startPrank(treasury);
        obsd.approve(address(vault), 500e18);
        vault.distributeRewards(500e18);
        vm.stopPrank();

        assertApproxEqAbs(vault.pendingRewards(alice), 500e18, 1);
    }

    function testFullUnstakeAndRestake() public {
        vm.startPrank(alice);
        obsd.approve(address(vault), 20_000e18);
        vault.stake(10_000e18);
        vm.stopPrank();

        // Distribute
        vm.startPrank(treasury);
        obsd.approve(address(vault), 1_000e18);
        vault.distributeRewards(1_000e18);
        vm.stopPrank();

        // Claim + full unstake
        vm.startPrank(alice);
        vault.claimRewards();
        vault.unstake(10_000e18);

        // Restake
        vault.stake(10_000e18);
        vm.stopPrank();

        // Should have 0 pending (no new distributions since restake)
        assertEq(vault.pendingRewards(alice), 0);

        // New distribution
        vm.startPrank(treasury);
        obsd.approve(address(vault), 1_000e18);
        vault.distributeRewards(1_000e18);
        vm.stopPrank();

        assertEq(vault.pendingRewards(alice), 1_000e18);
    }

    function testFuzz_StakeUnstake(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, 100_000e18);

        vm.startPrank(alice);
        obsd.approve(address(vault), stakeAmount);
        vault.stake(stakeAmount);

        assertEq(vault.staked(alice), stakeAmount);
        assertEq(vault.totalStaked(), stakeAmount);

        vault.unstake(stakeAmount);
        assertEq(vault.staked(alice), 0);
        assertEq(vault.totalStaked(), 0);
        vm.stopPrank();
    }

    function testFuzz_DistributeAndClaim(uint256 rewardAmount) public {
        rewardAmount = bound(rewardAmount, 1e18, 500_000e18);

        vm.startPrank(alice);
        obsd.approve(address(vault), 10_000e18);
        vault.stake(10_000e18);
        vm.stopPrank();

        vm.startPrank(treasury);
        obsd.approve(address(vault), rewardAmount);
        vault.distributeRewards(rewardAmount);
        vm.stopPrank();

        assertApproxEqAbs(vault.pendingRewards(alice), rewardAmount, 1);

        vm.prank(alice);
        vault.claimRewards();

        assertEq(vault.pendingRewards(alice), 0);
    }
}
