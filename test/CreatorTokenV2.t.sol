// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {CreatorTokenV2} from "../src/CreatorTokenV2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// --- Mocks ---

contract MockOBSD is ERC20 {
    constructor() ERC20("OBSD", "OBSD") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract MockAeroRouter {
    address public immutable factoryAddr;
    address public obsdToken;

    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    constructor(address factory_, address obsd_) {
        factoryAddr = factory_;
        obsdToken = obsd_;
    }

    function defaultFactory() external view returns (address) { return factoryAddr; }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        Route[] calldata,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        // Simulate: burn input tokens, mint 1:1 OBSD to recipient
        IERC20(msg.sender).transferFrom(msg.sender, address(this), amountIn);
        MockOBSD(obsdToken).mint(to, amountIn);

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }
}

// --- Tests ---

contract CreatorTokenV2Test is Test {
    CreatorTokenV2 token;
    MockOBSD obsd;
    MockAeroRouter router;

    address constant CREATOR = address(0xC1);
    address constant TREASURY = address(0xC2);
    address constant FACTORY = address(0xC3);
    address pool = makeAddr("pool");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant SUPPLY = 1_000_000_000e18;

    function setUp() public {
        obsd = new MockOBSD();
        router = new MockAeroRouter(makeAddr("aeroFactory"), address(obsd));

        // Deploy token from factory
        vm.startPrank(FACTORY);
        token = new CreatorTokenV2(
            "TestToken",
            "TEST",
            SUPPLY,
            FACTORY,       // recipient (factory holds all initially)
            CREATOR,
            TREASURY,
            address(obsd),
            address(router),
            FACTORY
        );
        token.setPool(pool);

        // Simulate: factory seeds pool, burns remaining
        // Transfer 80% to pool (simulating LP seeding)
        token.transfer(pool, SUPPLY * 80 / 100);
        // Burn remaining 20% (simulating burn at launch)
        token.burn(token.balanceOf(FACTORY));
        vm.stopPrank();
    }

    // ===== Basic Setup =====

    function test_setup_creatorHasZeroTokens() public view {
        assertEq(token.balanceOf(CREATOR), 0);
    }

    function test_setup_poolHasTokens() public view {
        assertEq(token.balanceOf(pool), SUPPLY * 80 / 100);
    }

    function test_setup_totalBurnedIncludesLaunchBurn() public view {
        assertEq(token.totalBurned(), SUPPLY * 20 / 100);
    }

    function test_setup_totalSupplyReduced() public view {
        assertEq(token.totalSupply(), SUPPLY * 80 / 100);
    }

    // ===== setPool =====

    function test_setPool_revertNotFactory() public {
        // Deploy a new token without pool set
        vm.prank(FACTORY);
        CreatorTokenV2 t2 = new CreatorTokenV2(
            "T2", "T2", SUPPLY, FACTORY, CREATOR, TREASURY,
            address(obsd), address(router), FACTORY
        );

        vm.prank(alice);
        vm.expectRevert("Only factory");
        t2.setPool(pool);
    }

    function test_setPool_revertAlreadySet() public {
        vm.prank(FACTORY);
        vm.expectRevert("Pool already set");
        token.setPool(makeAddr("other"));
    }

    // ===== Buy Flow (transfer from pool → user) =====

    function test_buy_appliesFees() public {
        uint256 buyAmount = 1_000_000e18;
        vm.prank(pool);
        token.transfer(alice, buyAmount);

        // 1% burn + 2% to contract (for OBSD swap) = 3% total
        uint256 expectedBurn = buyAmount * 100 / 10000; // 1%
        uint256 expectedSwap = buyAmount * 200 / 10000;  // 2%
        uint256 expectedNet = buyAmount - expectedBurn - expectedSwap;

        assertEq(token.balanceOf(alice), expectedNet);
    }

    function test_buy_burnReducesSupply() public {
        uint256 supplyBefore = token.totalSupply();

        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);

        uint256 burned = 1_000_000e18 * 100 / 10000; // 1% burn
        assertEq(token.totalSupply(), supplyBefore - burned);
    }

    function test_buy_setsLastBuyTimestamp() public {
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);

        assertEq(token.lastBuyTimestamp(alice), block.timestamp);
    }

    function test_buy_noExtraBurnOnBuy() public {
        // Even if alice had tokens before, buying should not trigger sell tax
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);

        uint256 totalFee = 1_000_000e18 * 300 / 10000; // 3%
        uint256 burnOnly = 1_000_000e18 * 100 / 10000;  // 1% burn
        uint256 expectedNet = 1_000_000e18 - totalFee;

        // No extra burn beyond the 1%
        assertEq(token.balanceOf(alice), expectedNet);
        // totalBurned should only include launch burn + 1% buy burn
        uint256 launchBurn = SUPPLY * 20 / 100;
        assertEq(token.totalBurned(), launchBurn + burnOnly);
    }

    // ===== Sell Flow (transfer from user → pool) =====

    function test_sell_within1Hour_5percentExtraBurn() public {
        // Buy first
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);
        uint256 aliceBalance = token.balanceOf(alice);

        // Sell immediately (within 1 hour) — 5% extra burn
        uint256 sellAmount = aliceBalance;
        uint256 baseBurn = sellAmount * 100 / 10000;   // 1%
        uint256 swapFee = sellAmount * 200 / 10000;     // 2%
        uint256 extraBurn = sellAmount * 500 / 10000;   // 5%
        uint256 expectedToPool = sellAmount - baseBurn - swapFee - extraBurn;

        uint256 supplyBefore = token.totalSupply();

        vm.prank(alice);
        token.transfer(pool, sellAmount);

        assertEq(token.balanceOf(pool) - (SUPPLY * 80 / 100 - 1_000_000e18), expectedToPool);
        // Total burned includes base + extra
        assertGt(token.totalBurned(), 0);
        assertEq(token.totalSupply(), supplyBefore - baseBurn - extraBurn);
    }

    function test_sell_after1Hour_3percentExtraBurn() public {
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);
        uint256 aliceBalance = token.balanceOf(alice);

        // Advance 2 hours
        vm.warp(block.timestamp + 2 hours);

        uint256 sellTax = token.getSellTax(alice);
        assertEq(sellTax, 300); // 3% (< 24h bracket)

        uint256 extraBurn = aliceBalance * 300 / 10000;
        uint256 supplyBefore = token.totalSupply();

        vm.prank(alice);
        token.transfer(pool, aliceBalance);

        uint256 baseBurn = aliceBalance * 100 / 10000;
        assertEq(token.totalSupply(), supplyBefore - baseBurn - extraBurn);
    }

    function test_sell_after24Hours_1percentExtraBurn() public {
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);

        vm.warp(block.timestamp + 2 days);

        uint256 sellTax = token.getSellTax(alice);
        assertEq(sellTax, 100); // 1% (< 7d bracket)
    }

    function test_sell_after7Days_zeroExtraBurn() public {
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);
        uint256 aliceBalance = token.balanceOf(alice);

        vm.warp(block.timestamp + 8 days);

        uint256 sellTax = token.getSellTax(alice);
        assertEq(sellTax, 0); // 0% (>= 7d)

        uint256 supplyBefore = token.totalSupply();

        vm.prank(alice);
        token.transfer(pool, aliceBalance);

        // Only 1% base burn, no extra
        uint256 baseBurn = aliceBalance * 100 / 10000;
        assertEq(token.totalSupply(), supplyBefore - baseBurn);
    }

    // ===== Regular Transfer (not buy/sell) =====

    function test_transfer_appliesBaseFeeOnly() public {
        // Give alice tokens via buy
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);
        uint256 aliceBalance = token.balanceOf(alice);

        // alice → bob (not pool, so no sell tax)
        uint256 sendAmount = aliceBalance / 2;
        uint256 baseBurn = sendAmount * 100 / 10000;
        uint256 swapFee = sendAmount * 200 / 10000;
        uint256 expectedNet = sendAmount - baseBurn - swapFee;

        vm.prank(alice);
        token.transfer(bob, sendAmount);

        assertEq(token.balanceOf(bob), expectedNet);
    }

    function test_transfer_noExtraBurnOnTransfer() public {
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);
        uint256 aliceBalance = token.balanceOf(alice);

        // Transfer to bob (not pool) — should have no sell tax even if held < 1hr
        uint256 supplyBefore = token.totalSupply();

        vm.prank(alice);
        token.transfer(bob, aliceBalance);

        uint256 baseBurn = aliceBalance * 100 / 10000;
        assertEq(token.totalSupply(), supplyBefore - baseBurn);
    }

    // ===== Fee Exempt =====

    function test_feeExempt_factoryPaysNoFees() public {
        // Factory is fee-exempt
        vm.prank(FACTORY);
        // Factory already transferred everything, but we can test the exemption
        assertTrue(token.feeExempt(FACTORY));
    }

    // ===== getSellTax =====

    function test_getSellTax_neverBought() public view {
        // Bob never bought — no timestamp
        assertEq(token.getSellTax(bob), 0);
    }

    function test_getSellTax_brackets() public {
        vm.prank(pool);
        token.transfer(alice, 1e18);

        // < 1 hour
        assertEq(token.getSellTax(alice), 500);

        // < 24 hours
        vm.warp(block.timestamp + 2 hours);
        assertEq(token.getSellTax(alice), 300);

        // < 7 days
        vm.warp(block.timestamp + 2 days);
        assertEq(token.getSellTax(alice), 100);

        // >= 7 days
        vm.warp(block.timestamp + 6 days);
        assertEq(token.getSellTax(alice), 0);
    }

    // ===== holdTime =====

    function test_holdTime_neverBought() public view {
        assertEq(token.holdTime(bob), type(uint256).max);
    }

    function test_holdTime_afterBuy() public {
        vm.prank(pool);
        token.transfer(alice, 1e18);

        vm.warp(block.timestamp + 100);
        assertEq(token.holdTime(alice), 100);
    }

    // ===== Supply Monotonically Decreasing =====

    function test_supplyDecreases_onEveryBuy() public {
        uint256 s0 = token.totalSupply();

        vm.prank(pool);
        token.transfer(alice, 100_000e18);

        uint256 s1 = token.totalSupply();
        assertLt(s1, s0);

        vm.prank(pool);
        token.transfer(bob, 100_000e18);

        uint256 s2 = token.totalSupply();
        assertLt(s2, s1);
    }

    function test_supplyDecreases_onSell() public {
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);

        uint256 sBefore = token.totalSupply();
        uint256 aliceBal = token.balanceOf(alice);

        vm.prank(alice);
        token.transfer(pool, aliceBal);

        assertLt(token.totalSupply(), sBefore);
    }

    function test_supplyDecreases_onTransfer() public {
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);

        uint256 sBefore = token.totalSupply();
        uint256 aliceBal = token.balanceOf(alice);

        vm.prank(alice);
        token.transfer(bob, aliceBal);

        assertLt(token.totalSupply(), sBefore);
    }

    // ===== OBSD Distribution =====

    function test_autoDistribute_sendsOBSD() public {
        // Do enough buys to exceed swap threshold
        uint256 threshold = token.swapThreshold();
        uint256 buyAmount = threshold * 100; // 2% of this goes to contract

        vm.prank(pool);
        token.transfer(alice, buyAmount);

        // Check OBSD was distributed (creator and treasury get equal shares)
        assertGt(obsd.balanceOf(CREATOR), 0);
        assertGt(obsd.balanceOf(TREASURY), 0);
        assertEq(obsd.balanceOf(CREATOR), obsd.balanceOf(TREASURY)); // equal split
        // Vault should also have OBSD (25% of swap OBSD)
        assertGt(token.backingVault(), 0);
    }

    function test_distribute_manual() public {
        // Small buy (below threshold)
        vm.prank(pool);
        token.transfer(alice, 10_000e18);

        // Pending fees accumulated but not yet distributed
        assertGt(token.pendingFees(), 0);
        assertEq(obsd.balanceOf(CREATOR), 0);

        // Manual trigger
        token.distribute();

        assertEq(token.pendingFees(), 0);
        assertGt(obsd.balanceOf(CREATOR), 0);
    }

    function test_distribute_revertNoPending() public {
        vm.expectRevert("No fees");
        token.distribute();
    }

    // ===== Burn Function =====

    function test_burn_reducesSupply() public {
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);

        uint256 aliceBal = token.balanceOf(alice);
        uint256 supplyBefore = token.totalSupply();

        vm.prank(alice);
        token.burn(aliceBal);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), supplyBefore - aliceBal);
    }

    // ===== Anti-Rug: Creator Cannot Dump =====

    function test_antiRug_creatorHasZeroTokens() public view {
        assertEq(token.balanceOf(CREATOR), 0);
    }

    function test_antiRug_creatorEarnsOBSDOnly() public {
        // Do trades — buy enough to trigger auto-distribute
        uint256 buyAmount = token.swapThreshold() * 100;
        vm.prank(pool);
        token.transfer(alice, buyAmount);

        // Creator has OBSD, not the token
        assertEq(token.balanceOf(CREATOR), 0);
        assertGt(obsd.balanceOf(CREATOR), 0);
    }

    // ===== IV Floor =====

    function test_iv_startsAtZero() public view {
        assertEq(token.iv(), 0);
        assertEq(token.backingVault(), 0);
    }

    function test_iv_growsAfterTrades() public {
        // Buy enough to trigger distribution (which seeds vault)
        uint256 buyAmount = token.swapThreshold() * 100;
        vm.prank(pool);
        token.transfer(alice, buyAmount);

        // After distribution, vault should have OBSD
        assertGt(token.backingVault(), 0);
        assertGt(token.iv(), 0);
    }

    function test_iv_neverDecreasesOnSell() public {
        // Buy to seed vault
        uint256 buyAmount = token.swapThreshold() * 100;
        vm.prank(pool);
        token.transfer(alice, buyAmount);

        uint256 ivBefore = token.iv();
        assertGt(ivBefore, 0);

        // Sell (should increase IV due to sell tax burn)
        uint256 aliceBal = token.balanceOf(alice);
        vm.prank(alice);
        token.transfer(pool, aliceBal / 2);

        // IV should not decrease (burns reduce circulating, vault unchanged from sell itself)
        assertGe(token.iv(), ivBefore);
    }

    function test_redeemAtIV() public {
        // Buy to seed vault
        uint256 buyAmount = token.swapThreshold() * 100;
        vm.prank(pool);
        token.transfer(alice, buyAmount);

        uint256 ivBefore = token.iv();
        uint256 aliceBal = token.balanceOf(alice);
        uint256 vaultBefore = token.backingVault();

        // Wait 7 days to minimize sell tax
        vm.warp(block.timestamp + 8 days);

        // Redeem half
        uint256 redeemAmount = aliceBal / 2;
        vm.prank(alice);
        token.redeemAtIV(redeemAmount);

        // Alice should have received OBSD
        assertGt(obsd.balanceOf(alice), 0);
        // Vault should have decreased
        assertLt(token.backingVault(), vaultBefore);
        // IV should be >= before (sell tax = 0% after 7d, so IV preserved exactly)
        assertGe(token.iv(), ivBefore);
    }

    function test_redeemAtIV_withSellTax_boostsIV() public {
        // Buy to seed vault
        uint256 buyAmount = token.swapThreshold() * 100;
        vm.prank(pool);
        token.transfer(alice, buyAmount);

        uint256 ivBefore = token.iv();

        // Redeem immediately (5% sell tax) — tax tokens burned with no OBSD payout
        uint256 aliceBal = token.balanceOf(alice);
        vm.prank(alice);
        token.redeemAtIV(aliceBal / 4);

        // IV should INCREASE because tax tokens were burned without reducing vault
        assertGt(token.iv(), ivBefore);
    }

    function test_redeemAtIV_revertZero() public {
        vm.prank(alice);
        vm.expectRevert("Zero amount");
        token.redeemAtIV(0);
    }

    function test_redeemAtIV_revertNoVault() public {
        // Give alice tokens but no vault
        vm.prank(pool);
        token.transfer(alice, 1000e18);

        vm.prank(alice);
        vm.expectRevert("No vault");
        token.redeemAtIV(100e18);
    }

    function test_seedVault() public {
        uint256 seedAmount = 1000e18;
        obsd.mint(FACTORY, seedAmount);

        vm.startPrank(FACTORY);
        obsd.approve(address(token), seedAmount);
        token.seedVault(seedAmount);
        vm.stopPrank();

        assertEq(token.backingVault(), seedAmount);
    }

    function test_seedVault_revertNotFactory() public {
        vm.prank(alice);
        vm.expectRevert("Only factory");
        token.seedVault(100e18);
    }

    function test_circulating_trackedOnBuy() public {
        assertEq(token.circulating(), 0);

        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);

        // Circulating = net tokens alice received (97% of buy)
        uint256 expected = 1_000_000e18 * 97 / 100; // 3% total fee
        assertEq(token.circulating(), expected);
    }

    function test_circulating_decreasesOnSell() public {
        vm.prank(pool);
        token.transfer(alice, 1_000_000e18);

        uint256 circBefore = token.circulating();
        uint256 aliceBal = token.balanceOf(alice);

        vm.prank(alice);
        token.transfer(pool, aliceBal);

        assertLt(token.circulating(), circBefore);
    }

    // ===== Fuzz: Supply Never Increases =====

    function testFuzz_supplyNeverIncreases(uint256 amount) public {
        uint256 poolBalance = token.balanceOf(pool);
        amount = bound(amount, 1e18, poolBalance / 2);

        uint256 s0 = token.totalSupply();

        // Buy
        vm.prank(pool);
        token.transfer(alice, amount);

        uint256 s1 = token.totalSupply();
        assertLe(s1, s0, "Supply increased on buy");

        // Sell (if alice has tokens)
        uint256 aliceBal = token.balanceOf(alice);
        if (aliceBal > 0) {
            vm.prank(alice);
            token.transfer(pool, aliceBal);

            uint256 s2 = token.totalSupply();
            assertLe(s2, s1, "Supply increased on sell");
        }
    }

    function testFuzz_ivNeverDecreases(uint256 buyAmount, uint256 sellFrac) public {
        uint256 poolBal = token.balanceOf(pool);
        buyAmount = bound(buyAmount, token.swapThreshold() * 10, poolBal / 4);
        sellFrac = bound(sellFrac, 10, 90); // sell 10-90% of balance

        // Buy (seeds vault via distribution)
        vm.prank(pool);
        token.transfer(alice, buyAmount);

        uint256 iv0 = token.iv();

        // Sell fraction
        uint256 aliceBal = token.balanceOf(alice);
        uint256 sellAmount = (aliceBal * sellFrac) / 100;
        if (sellAmount > 0 && token.circulating() > sellAmount) {
            vm.prank(alice);
            token.transfer(pool, sellAmount);

            uint256 iv1 = token.iv();
            assertGe(iv1, iv0, "IV decreased on sell");
        }
    }

    function testFuzz_ivNeverDecreasesOnRedeem(uint256 buyAmount, uint256 redeemFrac) public {
        uint256 poolBal = token.balanceOf(pool);
        buyAmount = bound(buyAmount, token.swapThreshold() * 10, poolBal / 4);
        redeemFrac = bound(redeemFrac, 5, 50); // redeem 5-50%

        // Buy
        vm.prank(pool);
        token.transfer(alice, buyAmount);

        uint256 iv0 = token.iv();
        if (iv0 == 0 || token.backingVault() == 0) return;

        // Redeem
        uint256 aliceBal = token.balanceOf(alice);
        uint256 redeemAmount = (aliceBal * redeemFrac) / 100;
        if (redeemAmount > 0 && token.circulating() > redeemAmount) {
            vm.prank(alice);
            token.redeemAtIV(redeemAmount);

            uint256 iv1 = token.iv();
            assertGe(iv1, iv0, "IV decreased on redeem");
        }
    }

    function testFuzz_sellTaxDecreasesOverTime(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, 30 days);

        vm.prank(pool);
        token.transfer(alice, 1e18);

        vm.warp(block.timestamp + elapsed);

        uint256 tax = token.getSellTax(alice);

        if (elapsed < 1 hours) assertEq(tax, 500);
        else if (elapsed < 24 hours) assertEq(tax, 300);
        else if (elapsed < 7 days) assertEq(tax, 100);
        else assertEq(tax, 0);
    }
}
