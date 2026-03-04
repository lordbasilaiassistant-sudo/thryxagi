// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EverRise} from "../src/EverRise.sol";

contract EverRiseTest is Test {
    EverRise public token;
    address public creator = address(0xC0FFEE);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public charlie = address(0xC4A4);

    function setUp() public {
        token = new EverRise(creator, 1 ether); // conservative config
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }

    // ============================================================
    //  BASIC BUY/SELL
    // ============================================================

    function test_buy_basic() public {
        vm.prank(alice);
        token.buy{value: 1 ether}(0);

        assertGt(token.balanceOf(alice), 0, "Alice should have tokens");
        assertGt(token.realETH(), 0, "Treasury should have ETH");
        assertGt(token.circulating(), 0, "Circulating should increase");
        assertGt(token.iv(), 0, "IV should be > 0");
        assertGt(creator.balance, 0, "Creator should receive fee");
    }

    function test_sell_after_buy() public {
        vm.prank(alice);
        token.buy{value: 1 ether}(0);

        uint256 bal = token.balanceOf(alice);
        uint256 maxSell = bal * 2500 / 10000; // 25% max

        // Advance 1 block for cooldown
        vm.roll(block.number + 1);
        // Advance time for lower tax
        vm.warp(block.timestamp + 31 days);

        vm.prank(alice);
        token.sell(maxSell, 0);

        assertLt(token.balanceOf(alice), bal, "Balance should decrease");
        assertGt(alice.balance, 99 ether, "Alice should get some ETH back");
    }

    // ============================================================
    //  IV INVARIANT — the critical property
    // ============================================================

    function test_iv_never_decreases_on_buy() public {
        // First buy to establish IV
        vm.prank(alice);
        token.buy{value: 0.5 ether}(0);
        uint256 iv1 = token.iv();

        vm.prank(bob);
        token.buy{value: 1 ether}(0);
        uint256 iv2 = token.iv();

        assertGe(iv2, iv1, "IV must not decrease on buy");

        vm.prank(charlie);
        token.buy{value: 2 ether}(0);
        uint256 iv3 = token.iv();

        assertGe(iv3, iv2, "IV must not decrease on buy (2)");
    }

    function test_iv_never_decreases_on_sell() public {
        // Setup: multiple buyers
        vm.prank(alice);
        token.buy{value: 2 ether}(0);

        vm.roll(block.number + 1);

        vm.prank(bob);
        token.buy{value: 1 ether}(0);

        uint256 ivBefore = token.iv();
        uint256 maxSell = token.balanceOf(alice) * 2500 / 10000;

        // Sell — advance block so alice can sell
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 hours);

        vm.prank(alice);
        token.sell(maxSell, 0);

        uint256 ivAfter = token.iv();
        assertGe(ivAfter, ivBefore, "IV must not decrease on sell");
    }

    function test_iv_stress_100_trades() public {
        address[5] memory traders = [alice, bob, charlie, address(0xD0D), address(0xE0E)];
        for (uint i = 3; i < 5; i++) {
            vm.deal(traders[i], 100 ether);
        }

        // 50 buys
        for (uint i = 0; i < 50; i++) {
            address t = traders[i % 5];
            uint256 ivBefore = token.iv();
            vm.prank(t);
            token.buy{value: 0.1 ether + (i * 0.01 ether)}(0);
            assertGe(token.iv(), ivBefore, "IV decreased on buy");
        }

        // 50 sells (advance time so tax is low)
        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 31 days);

        for (uint i = 0; i < 50; i++) {
            address t = traders[i % 5];
            uint256 bal = token.balanceOf(t);
            if (bal == 0) continue;

            uint256 sellAmt = bal * 500 / 10000; // 5% per sell
            if (sellAmt == 0) continue;
            if (token.circulating() - sellAmt < 1e18) continue;

            uint256 ivBefore = token.iv();
            vm.prank(t);
            token.sell(sellAmt, 0);
            assertGe(token.iv(), ivBefore, "IV decreased on sell");
        }
    }

    // ============================================================
    //  SPOT PRICE ONLY GOES UP
    // ============================================================

    function test_spot_only_increases() public {
        uint256 spot1 = token.spotPrice();

        vm.prank(alice);
        token.buy{value: 0.5 ether}(0);
        uint256 spot2 = token.spotPrice();
        assertGt(spot2, spot1, "Spot should increase on buy");

        vm.prank(bob);
        token.buy{value: 1 ether}(0);

        // Sell doesn't touch curve — spot unchanged
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 days);
        uint256 spotBeforeSell = token.spotPrice();
        uint256 sellAmt = token.balanceOf(alice) * 500 / 10000;
        vm.prank(alice);
        token.sell(sellAmt, 0);
        uint256 spot3 = token.spotPrice();
        assertEq(spot3, spotBeforeSell, "Spot should not change on sell");
    }

    // ============================================================
    //  SECURITY TESTS
    // ============================================================

    function test_revert_sameBlockSell() public {
        vm.prank(alice);
        token.buy{value: 1 ether}(0);

        // Same block sell should revert
        vm.prank(alice);
        vm.expectRevert("Same-block sell");
        token.sell(1e18, 0);
    }

    function test_revert_belowMinBuy() public {
        vm.prank(alice);
        vm.expectRevert("Below min buy");
        token.buy{value: 0.00001 ether}(0);
    }

    function test_revert_aboveMaxBuy() public {
        vm.prank(alice);
        vm.expectRevert("Above max buy");
        token.buy{value: 6 ether}(0);
    }

    function test_slippage_protection_buy() public {
        vm.prank(alice);
        vm.expectRevert("Slippage");
        token.buy{value: 0.001 ether}(type(uint256).max); // impossible amount
    }

    function test_slippage_protection_sell() public {
        vm.prank(alice);
        token.buy{value: 1 ether}(0);

        uint256 sellAmt = token.balanceOf(alice) * 2500 / 10000;

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 31 days);
        vm.prank(alice);
        vm.expectRevert("Slippage");
        token.sell(sellAmt, type(uint256).max);
    }

    function test_transfer_resets_tax_timer() public {
        vm.prank(alice);
        token.buy{value: 1 ether}(0);

        // Advance time so Alice has low tax
        vm.warp(block.timestamp + 31 days);

        // Transfer to Bob — his timer should reset
        uint256 halfBal = token.balanceOf(alice) / 2;
        vm.prank(alice);
        token.transfer(bob, halfBal);

        // Bob's lastBuyTimestamp should be now
        assertEq(token.lastBuyTimestamp(bob), block.timestamp);
    }

    function test_sell_capped_at_25pct() public {
        vm.prank(alice);
        token.buy{value: 2 ether}(0);

        uint256 bal = token.balanceOf(alice);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 31 days);

        vm.prank(alice);
        token.sell(bal, 0); // tries to sell 100%

        // Should only have sold 25%
        uint256 expected = bal - (bal * 2500 / 10000);
        assertEq(token.balanceOf(alice), expected, "Should cap at 25%");
    }

    function test_min_circulating_floor() public {
        vm.prank(alice);
        token.buy{value: 0.001 ether}(0); // small buy

        uint256 bal = token.balanceOf(alice);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 31 days);

        // If selling would drop below MIN_CIRCULATING, it should revert
        if (token.circulating() - (bal * 2500 / 10000) < 1e18) {
            vm.prank(alice);
            vm.expectRevert("Below min supply");
            token.sell(bal, 0);
        }
    }

    // ============================================================
    //  CREATOR EARNINGS
    // ============================================================

    function test_creator_earns_on_buys() public {
        uint256 creatorBefore = creator.balance;

        vm.prank(alice);
        token.buy{value: 1 ether}(0);

        uint256 earned = creator.balance - creatorBefore;
        assertEq(earned, 0.01 ether, "Creator should get 1% of buy");
    }

    function test_creator_earns_on_sells() public {
        vm.prank(alice);
        token.buy{value: 5 ether}(0); // need decent treasury (max buy is 5 ETH)

        uint256 creatorBefore = creator.balance;
        uint256 sellAmt = token.balanceOf(alice) * 2500 / 10000;

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 31 days);

        vm.prank(alice);
        token.sell(sellAmt, 0);

        uint256 earned = creator.balance - creatorBefore;
        assertGt(earned, 0, "Creator should earn on sell");
    }

    // ============================================================
    //  ESTIMATE FUNCTIONS
    // ============================================================

    function test_estimateBuy() public {
        (uint256 est, uint256 burned) = token.estimateBuy(1 ether);
        assertGt(est, 0);
        assertGt(burned, 0);

        vm.prank(alice);
        token.buy{value: 1 ether}(0);

        assertEq(token.balanceOf(alice), est, "Estimate should match actual");
    }
}
