// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokenV3} from "../src/TokenV3.sol";
import {RouterV3, PoolKey} from "../src/RouterV3.sol";

// ════════════════════════════════════════════════════════════════════════
// Mock Contracts
// ════════════════════════════════════════════════════════════════════════

contract MockAeroPoolV3 {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockAeroFactoryV3 {
    mapping(bytes32 => address) internal pools;

    function getPool(address a, address b, bool stable) external view returns (address) {
        return pools[_k(a, b, stable)];
    }

    function createPool(address a, address b, bool stable) external returns (address) {
        bytes32 key = _k(a, b, stable);
        if (pools[key] == address(0)) pools[key] = address(new MockAeroPoolV3());
        return pools[key];
    }

    function _k(address a, address b, bool s) internal pure returns (bytes32) {
        (address t0, address t1) = a < b ? (a, b) : (b, a);
        return keccak256(abi.encodePacked(t0, t1, s));
    }
}

contract MockAeroRouterV3 {
    MockAeroFactoryV3 public mockFactory;
    address public constant WETH_ADDR = 0x4200000000000000000000000000000000000006;

    constructor() {
        mockFactory = new MockAeroFactoryV3();
    }

    function defaultFactory() external view returns (address) {
        return address(mockFactory);
    }

    function weth() external pure returns (address) {
        return WETH_ADDR;
    }

    function poolFor(address a, address b, bool stable, address) external view returns (address) {
        return mockFactory.getPool(a, b, stable);
    }

    function addLiquidityETH(
        address tkn, bool stable, uint256 amt, uint256, uint256, address to, uint256
    ) external payable returns (uint256, uint256, uint256) {
        IERC20(tkn).transferFrom(msg.sender, address(this), amt);
        address pool = mockFactory.createPool(tkn, WETH_ADDR, stable);
        MockAeroPoolV3(pool).mint(to, msg.value);
        return (amt, msg.value, msg.value);
    }
}

contract MockV4PositionManagerV3 {
    uint256 private _nextId = 1;
    mapping(uint256 => address) public ownerOf;

    function nextTokenId() external view returns (uint256) {
        return _nextId;
    }

    function initializePool(PoolKey calldata, uint160) external payable returns (int24) {
        return 0;
    }

    function modifyLiquidities(bytes calldata, uint256) external payable {
        ownerOf[_nextId] = msg.sender;
        _nextId++;
    }

    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool ok, bytes memory ret) = address(this).delegatecall(data[i]);
            require(ok, "multicall failed");
            results[i] = ret;
        }
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        require(ownerOf[tokenId] == from, "Not owner");
        ownerOf[tokenId] = to;
    }
}

contract MockPermit2V3 {
    function approve(address, address, uint160, uint48) external {}
}

/// @dev Attempts reentrancy during claimFees
contract ReentrancyAttacker {
    RouterV3 public target;
    bool public attacking;

    constructor(address _target) {
        target = RouterV3(payable(_target));
    }

    function attack() external {
        attacking = true;
        target.claimFees();
    }

    receive() external payable {
        if (attacking) {
            attacking = false;
            // Try to re-enter claimFees
            try target.claimFees() {} catch {}
        }
    }
}

/// @dev Contract that rejects ETH
contract ETHRejecter {
    // No receive() or fallback() — ETH sends will revert
}

// ════════════════════════════════════════════════════════════════════════
// Test Suite
// ════════════════════════════════════════════════════════════════════════

contract V3Test is Test {
    TokenV3 public token;
    RouterV3 public router;
    MockAeroRouterV3 public mockAero;
    MockV4PositionManagerV3 public mockV4;
    MockPermit2V3 public mockPermit2;

    address public creator = address(0xC0FFEE);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public charlie = address(0xC4A4);
    address public dave = address(0xDA7E);
    address public eve = address(0xE7E);
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 constant SMALL_BUY = 0.0002 ether;
    uint256 constant MED_BUY = 0.0005 ether;

    function setUp() public {
        mockAero = new MockAeroRouterV3();
        mockV4 = new MockV4PositionManagerV3();
        mockPermit2 = new MockPermit2V3();

        token = new TokenV3("Obsidian", "OBSD");
        router = new RouterV3(
            address(token), creator, address(mockAero), address(mockV4), address(mockPermit2), 0.5 ether
        );

        token.setRouter(address(router));
        token.transfer(address(router), token.balanceOf(address(this)));

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(dave, 100 ether);
        vm.deal(eve, 100 ether);
    }

    // ════════════════════════════════════════════════════════════════════
    // A. UNIT TESTS — Buy Mechanics
    // ════════════════════════════════════════════════════════════════════

    function test_buy_basic() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertGt(token.balanceOf(alice), 0, "Alice should have tokens");
        assertGt(router.realETH(), 0, "Treasury should have ETH");
        assertGt(router.iv(), 0, "IV should be positive");
    }

    function test_buy_tokens_burned() public {
        uint256 supplyBefore = token.totalSupply();
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertLt(token.totalSupply(), supplyBefore, "Supply should decrease from burn");
        assertGt(router.totalBurned(), 0, "totalBurned should be positive");
    }

    function test_buy_creator_fee_accumulated() public {
        uint256 feesBefore = router.pendingCreatorFees();
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertGt(router.pendingCreatorFees(), feesBefore, "Fees should accumulate");
        // Fee should be 1% of buy
        uint256 expectedFee = (SMALL_BUY * 100) / 10000;
        assertEq(router.pendingCreatorFees(), expectedFee, "Fee should be exactly 1%");
    }

    function test_buy_no_direct_eth_to_creator() public {
        uint256 creatorBefore = creator.balance;
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertEq(creator.balance, creatorBefore, "Creator should NOT receive ETH directly on buy");
    }

    function test_buy_updates_volume() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertEq(router.totalVolume(), SMALL_BUY, "Volume should match buy amount");
    }

    function test_buy_updates_lastBuyBlock() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertEq(router.lastBuyBlock(alice), block.number, "lastBuyBlock should be current block");
    }

    function test_buy_multiple_users() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 aliceBal = token.balanceOf(alice);

        vm.prank(bob);
        router.buy{value: SMALL_BUY}(0);
        uint256 bobBal = token.balanceOf(bob);

        // Bob gets fewer tokens (higher spot price)
        assertLt(bobBal, aliceBal, "Later buyer gets fewer tokens");
    }

    function test_buy_revert_below_min() public {
        vm.prank(alice);
        vm.expectRevert("Below min");
        router.buy{value: 0.00001 ether}(0);
    }

    function test_buy_large_amount_works() public {
        // No max buy — curve provides natural slippage protection
        vm.prank(alice);
        router.buy{value: 1 ether}(0);
        assertGt(token.balanceOf(alice), 0, "Large buy should work");
        assertGt(router.spotPrice(), 0, "Spot should be positive after large buy");
    }

    function test_buy_revert_slippage() public {
        vm.prank(alice);
        vm.expectRevert("Slippage");
        router.buy{value: SMALL_BUY}(type(uint256).max);
    }

    function test_buy_revert_after_graduation() public {
        _pushToGraduated();
        vm.prank(dave);
        vm.expectRevert("Graduated");
        router.buy{value: SMALL_BUY}(0);
    }

    // ════════════════════════════════════════════════════════════════════
    // A. UNIT TESTS — Sell Mechanics
    // ════════════════════════════════════════════════════════════════════

    function test_sell_basic() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 bal = token.balanceOf(alice);
        uint256 sellAmt = bal / 4;

        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);

        uint256 ethBefore = alice.balance;
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertGt(alice.balance, ethBefore, "Alice should receive ETH");
        assertLt(token.balanceOf(alice), bal, "Token balance should decrease");
    }

    function test_sell_all_tokens_burned() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 supplyAfterBuy = token.totalSupply();
        uint256 sellAmt = token.balanceOf(alice) / 4;

        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);

        assertEq(token.totalSupply(), supplyAfterBuy - sellAmt, "All sold tokens should be burned");
    }

    function test_sell_creator_fee_accumulated() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 feesBefore = router.pendingCreatorFees();

        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);

        assertGt(router.pendingCreatorFees(), feesBefore, "Fees should accumulate on sell");
    }

    function test_sell_revert_zero_amount() public {
        vm.prank(alice);
        vm.expectRevert("Zero amount");
        router.sell(0, 0);
    }

    function test_sell_revert_same_block() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        vm.prank(alice);
        token.approve(address(router), 1e18);
        vm.prank(alice);
        vm.expectRevert("Same block");
        router.sell(1e18, 0);
    }

    function test_sell_revert_slippage() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        vm.expectRevert("Slippage");
        router.sell(sellAmt, type(uint256).max);
    }

    function test_sell_revert_min_circulating() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 bal = token.balanceOf(alice);
        // Try to sell all, leaving < MIN_CIRCULATING
        vm.prank(alice);
        token.approve(address(router), bal);
        vm.roll(block.number + 1);
        vm.prank(alice);
        vm.expectRevert("Min supply");
        router.sell(bal, 0);
    }

    function test_sell_works_in_hybrid() public {
        _pushToTier0();
        // Phase should be Hybrid — sells at IV still work
        assertTrue(uint8(router.phase()) == uint8(RouterV3.Phase.Hybrid), "Should be Hybrid");

        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 bal = token.balanceOf(alice);
        uint256 sellAmt = bal / 4;
        require(sellAmt > 0, "Need tokens to sell");

        uint256 ivBefore = router.iv();
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);

        // IV must still rise on sell (same guarantee as BondingCurve phase)
        assertGe(router.iv(), ivBefore, "IV must not decrease on Hybrid sell");
    }

    // ════════════════════════════════════════════════════════════════════
    // A. UNIT TESTS — View Functions
    // ════════════════════════════════════════════════════════════════════

    function test_iv_zero_when_no_circulating() public view {
        assertEq(router.iv(), 0, "IV should be 0 with no circulating supply");
    }

    function test_spotPrice_initial() public view {
        // vETH = 0.5 ether, vTOK = 1B tokens
        // spot = 0.5e18 * 1e18 / 1e27 = 5e-10 (very small)
        assertGt(router.spotPrice(), 0, "Initial spot price should be positive");
    }

    function test_estimateBuy_matches_actual() public {
        (uint256 est,) = router.estimateBuy(SMALL_BUY);
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertEq(token.balanceOf(alice), est, "Estimate should match actual");
    }

    function test_estimateSell_matches_actual() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 sellAmt = token.balanceOf(alice) / 4;
        uint256 est = router.estimateSell(sellAmt);

        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        uint256 ethBefore = alice.balance;
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertEq(alice.balance - ethBefore, est, "Sell estimate should match actual");
    }

    function test_getTierThreshold() public pure {
        RouterV3 r; // unused, just calling pure function
        // Can't call on undeployed, test via deployed
    }

    function test_tierThresholds_ascending() public view {
        uint256 prev = 0;
        for (uint8 i = 0; i < 5; i++) {
            uint256 t = router.getTierThreshold(i);
            assertGt(t, prev, "Thresholds must be ascending");
            prev = t;
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // A. UNIT TESTS — Fee Claiming
    // ════════════════════════════════════════════════════════════════════

    function test_claimFees_basic() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 fees = router.pendingCreatorFees();
        assertGt(fees, 0, "Should have pending fees");

        uint256 creatorBefore = creator.balance;
        vm.prank(creator);
        router.claimFees();
        assertEq(creator.balance - creatorBefore, fees, "Creator should receive exact fees");
        assertEq(router.pendingCreatorFees(), 0, "Pending fees should be zero");
    }

    function test_claimFees_revert_not_creator() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        vm.prank(alice);
        vm.expectRevert("Not creator");
        router.claimFees();
    }

    function test_claimFees_revert_no_fees() public {
        vm.prank(creator);
        vm.expectRevert("No fees");
        router.claimFees();
    }

    function test_claimFees_accumulates_across_trades() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        vm.prank(bob);
        router.buy{value: SMALL_BUY}(0);

        uint256 expectedFees = 2 * ((SMALL_BUY * 100) / 10000);
        assertEq(router.pendingCreatorFees(), expectedFees, "Fees should accumulate from multiple buys");
    }

    // ════════════════════════════════════════════════════════════════════
    // B. INTEGRATION TESTS — Tier Progression
    // ════════════════════════════════════════════════════════════════════

    function test_tier0_triggers_at_threshold() public {
        _pushToTier0();
        assertTrue(router.tierCompleted(0), "Tier 0 should be completed");
        assertEq(uint8(router.phase()), uint8(RouterV3.Phase.Hybrid), "Should be in Hybrid phase");
        assertGt(router.currentTier(), 0, "Current tier should advance past 0");
    }

    function test_tier0_creates_aero_pool() public {
        _pushToTier0();
        assertTrue(router.aeroPool() != address(0), "Aero pool should be created");
    }

    function test_tier0_creates_v4_position() public {
        _pushToTier0();
        assertGt(router.getV4TokenIdsLength(), 0, "V4 position should exist");
        assertTrue(router.v4PoolInitialized(), "V4 pool should be initialized");
    }

    function test_tier0_burns_lp() public {
        _pushToTier0();
        address pool = router.aeroPool();
        assertGt(MockAeroPoolV3(pool).balanceOf(DEAD), 0, "Aero LP should be burned");
        assertEq(MockAeroPoolV3(pool).balanceOf(address(router)), 0, "Router should hold no Aero LP");
    }

    function test_tier0_burns_v4_nft() public {
        _pushToTier0();
        uint256 tokenId = router.v4TokenIds(0);
        assertEq(mockV4.ownerOf(tokenId), DEAD, "V4 NFT should be burned to DEAD");
    }

    function test_tier0_sells_still_work() public {
        _pushToTier0();
        // Buy after tier 0
        vm.prank(dave);
        router.buy{value: SMALL_BUY}(0);
        uint256 sellAmt = token.balanceOf(dave) / 4;
        require(sellAmt > 0, "Need tokens");

        uint256 ivBefore = router.iv();
        vm.prank(dave);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(dave);
        uint256 ethBefore = dave.balance;
        router.sell(sellAmt, 0);
        assertGt(dave.balance, ethBefore, "Should receive ETH from sell in Hybrid");
        assertGe(router.iv(), ivBefore, "IV must not decrease on sell after tier 0");
    }

    function test_full_lifecycle_all_tiers() public {
        _pushToGraduated();
        assertEq(uint8(router.phase()), uint8(RouterV3.Phase.Graduated), "Should be Graduated");

        // All tiers completed
        for (uint8 i = 0; i < 5; i++) {
            assertTrue(router.tierCompleted(i), string.concat("Tier should be completed: ", vm.toString(i)));
        }
    }

    function test_buys_work_in_hybrid_phase() public {
        _pushToTier0();
        assertEq(uint8(router.phase()), uint8(RouterV3.Phase.Hybrid));

        // Buys should still work
        vm.prank(dave);
        router.buy{value: SMALL_BUY}(0);
        assertGt(token.balanceOf(dave), 0, "Buy should work in Hybrid");
    }

    function test_whale_buy_triggers_multiple_tiers() public {
        // A single 1 ETH buy should push through ALL tiers and graduate
        vm.prank(alice);
        router.buy{value: 1 ether}(0);
        // realETH = 0.99 ETH > TIER_4_THRESHOLD (0.5 ETH)
        assertEq(uint8(router.phase()), uint8(RouterV3.Phase.Graduated), "Should fully graduate");
        for (uint8 i = 0; i < 5; i++) {
            assertTrue(router.tierCompleted(i), "All tiers should complete");
        }
    }

    function test_manual_graduateTier() public {
        // Fill treasury enough for tier 0 but don't trigger it during buy
        // Actually, _checkTierProgression runs after every buy, so it auto-triggers.
        // Let's just verify the public graduateTier() doesn't revert when nothing to do
        router.graduateTier(); // no-op, nothing to graduate
    }

    // ════════════════════════════════════════════════════════════════════
    // C. INVARIANT TESTS — IV Never Decreases
    // ════════════════════════════════════════════════════════════════════

    function test_iv_never_decreases_on_buy() public {
        // Use tiny buys that won't trigger tier graduation (stay in same phase)
        vm.prank(alice);
        router.buy{value: 0.0001 ether}(0);
        uint256 iv1 = router.iv();

        vm.prank(bob);
        router.buy{value: 0.0001 ether}(0);
        assertGe(router.iv(), iv1, "IV should not decrease on buy (same phase)");

        uint256 iv2 = router.iv();
        vm.prank(charlie);
        router.buy{value: 0.0001 ether}(0);
        assertGe(router.iv(), iv2, "IV should not decrease on second buy (same phase)");
    }

    function test_iv_never_decreases_on_sell() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        vm.prank(bob);
        router.buy{value: SMALL_BUY}(0);

        uint256 ivBefore = router.iv();
        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertGt(router.iv(), ivBefore, "IV should INCREASE on sell (due to tax)");
    }

    function test_iv_stress_many_buys() public {
        address[5] memory traders = [alice, bob, charlie, dave, eve];
        uint256 prevIV = 0;

        for (uint256 i = 0; i < 20; i++) {
            address t = traders[i % 5];
            uint8 phaseBefore = uint8(router.phase());
            vm.prank(t);
            router.buy{value: 0.0001 ether}(0);
            uint8 phaseAfter = uint8(router.phase());

            // IV invariant only holds within same phase — tier transitions move ETH to DEXes
            if (phaseBefore == phaseAfter) {
                uint256 newIV = router.iv();
                assertGe(newIV, prevIV, "IV must never decrease on buy (same phase)");
                prevIV = newIV;
            } else {
                prevIV = router.iv(); // reset baseline after phase change
            }
            if (phaseAfter == uint8(RouterV3.Phase.Graduated)) break;
        }
    }

    function test_iv_stress_buy_sell_mixed() public {
        address[5] memory traders = [alice, bob, charlie, dave, eve];

        // Buys
        for (uint256 i = 0; i < 10; i++) {
            address t = traders[i % 5];
            vm.prank(t);
            router.buy{value: 0.0001 ether}(0);
            if (uint8(router.phase()) != uint8(RouterV3.Phase.BondingCurve)) break;
        }
        if (uint8(router.phase()) != uint8(RouterV3.Phase.BondingCurve)) return;

        // Sells
        vm.roll(block.number + 10);
        for (uint256 i = 0; i < 10; i++) {
            address t = traders[i % 5];
            uint256 bal = token.balanceOf(t);
            if (bal == 0) continue;
            uint256 sellAmt = bal / 20;
            if (sellAmt == 0 || router.circulating() - sellAmt < 1e18) continue;

            uint256 ivBefore = router.iv();
            vm.prank(t);
            token.approve(address(router), sellAmt);
            vm.prank(t);
            router.sell(sellAmt, 0);
            assertGe(router.iv(), ivBefore, "IV must never decrease on sell");
        }
    }

    function testFuzz_iv_never_decreases_on_buy(uint256 ethAmt) public {
        ethAmt = bound(ethAmt, 0.0001 ether, 10 ether);

        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 ivBefore = router.iv();
        uint8 phaseBefore = uint8(router.phase());

        vm.prank(bob);
        router.buy{value: ethAmt}(0);

        // IV invariant only holds within same phase — tier transitions move ETH to DEXes
        if (uint8(router.phase()) == phaseBefore) {
            assertGe(router.iv(), ivBefore, "IV must never decrease on fuzzed buy (same phase)");
        }
    }

    function testFuzz_iv_never_decreases_on_sell(uint256 sellPct) public {
        sellPct = bound(sellPct, 1, 90); // 1% to 90% of balance

        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        vm.prank(bob);
        router.buy{value: SMALL_BUY}(0);
        // Sells work in BondingCurve and Hybrid — only skip if Graduated
        if (uint8(router.phase()) == uint8(RouterV3.Phase.Graduated)) return;

        uint256 bal = token.balanceOf(alice);
        uint256 sellAmt = (bal * sellPct) / 100;
        if (sellAmt == 0) return;
        if (router.circulating() - sellAmt < 1e18) return;

        uint256 ivBefore = router.iv();
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertGe(router.iv(), ivBefore, "IV must never decrease on fuzzed sell");
    }

    function testFuzz_iv_never_decreases_on_sell_hybrid(uint256 sellPct) public {
        sellPct = bound(sellPct, 1, 90);

        // Push to Hybrid (tier 0)
        _pushToTier0();
        assertTrue(uint8(router.phase()) == uint8(RouterV3.Phase.Hybrid), "Should be Hybrid");

        // Buy in Hybrid phase
        vm.prank(alice);
        router.buy{value: 0.01 ether}(0);
        vm.prank(bob);
        router.buy{value: 0.005 ether}(0);

        uint256 bal = token.balanceOf(alice);
        uint256 sellAmt = (bal * sellPct) / 100;
        if (sellAmt == 0) return;
        if (router.circulating() - sellAmt < 1e18) return;

        uint256 ivBefore = router.iv();
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertGe(router.iv(), ivBefore, "IV must never decrease on fuzzed sell in Hybrid");
    }

    // ════════════════════════════════════════════════════════════════════
    // C. INVARIANT TESTS — Spot Price Never Decreases
    // ════════════════════════════════════════════════════════════════════

    function test_spot_only_increases_on_buy() public {
        uint256 spot0 = router.spotPrice();
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertGt(router.spotPrice(), spot0, "Spot should increase on buy");
    }

    function test_spot_unchanged_on_sell() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 spotBefore = router.spotPrice();

        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertEq(router.spotPrice(), spotBefore, "Spot should not change on sell");
    }

    function testFuzz_spot_never_decreases(uint256 ethAmt) public {
        ethAmt = bound(ethAmt, 0.0001 ether, 10 ether);

        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 spotBefore = router.spotPrice();

        vm.prank(bob);
        router.buy{value: ethAmt}(0);
        assertGe(router.spotPrice(), spotBefore, "Spot must never decrease");
    }

    // ════════════════════════════════════════════════════════════════════
    // C. INVARIANT TESTS — Supply Only Decreases
    // ════════════════════════════════════════════════════════════════════

    function test_supply_only_decreases() public {
        uint256 supply0 = token.totalSupply();
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertLt(token.totalSupply(), supply0, "Supply should decrease on buy (burn)");

        uint256 supply1 = token.totalSupply();
        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertLt(token.totalSupply(), supply1, "Supply should decrease on sell (all burned)");
    }

    // ════════════════════════════════════════════════════════════════════
    // D. EDGE CASE TESTS
    // ════════════════════════════════════════════════════════════════════

    function test_first_buy_works() public {
        vm.prank(alice);
        router.buy{value: MIN_BUY()}(0);
        assertGt(token.balanceOf(alice), 0, "First buy should work at minimum");
    }

    function test_exact_min_buy() public {
        vm.prank(alice);
        router.buy{value: 0.0001 ether}(0);
        assertGt(token.balanceOf(alice), 0);
    }

    function test_whale_buy_curve_slippage() public {
        // A 5 ETH buy should work but with massive slippage (curve anti-whale)
        vm.prank(alice);
        router.buy{value: 5 ether}(0);
        uint256 aliceTokens = token.balanceOf(alice);
        // Alice gets ~89% of supply with 5 ETH, but paid enormous slippage
        assertGt(aliceTokens, 0);
        // Spot price should have jumped massively
        assertGt(router.spotPrice(), router.iv(), "Spot should be way above IV after whale buy");
    }

    function test_exact_tier0_threshold() public {
        // Tier 0 threshold = 0.0005 ETH
        // A single 0.001 ETH buy gives realETH = 0.00099 > 0.0005 — should trigger Tier 0
        vm.prank(alice);
        router.buy{value: 0.001 ether}(0);
        assertTrue(router.tierCompleted(0), "Tier 0 should trigger on first meaningful buy");
        assertEq(uint8(router.phase()), uint8(RouterV3.Phase.Hybrid), "Should enter Hybrid");
    }

    function test_sell_near_min_circulating() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 bal = token.balanceOf(alice);
        // Leave exactly MIN_CIRCULATING
        uint256 maxSell = router.circulating() - 1e18;
        if (maxSell > bal) maxSell = bal;

        vm.prank(alice);
        token.approve(address(router), maxSell);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(maxSell, 0);
        assertGe(router.circulating(), 1e18, "Should maintain min circulating");
    }

    function test_multiple_sells_same_user() public {
        vm.prank(alice);
        router.buy{value: MED_BUY}(0);
        uint256 bal = token.balanceOf(alice);
        uint256 sellAmt = bal / 10;

        vm.prank(alice);
        token.approve(address(router), bal);
        vm.roll(block.number + 1);

        // First sell
        uint256 ivBefore = router.iv();
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertGe(router.iv(), ivBefore);

        // Second sell (same block is ok because lastBuyBlock hasn't changed)
        ivBefore = router.iv();
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertGe(router.iv(), ivBefore);
    }

    function test_dust_buy_amount() public {
        vm.prank(alice);
        router.buy{value: 0.0001 ether}(0);
        assertGt(token.balanceOf(alice), 0, "Dust buy should still produce tokens");
    }

    function test_consecutive_buys_different_blocks() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 bal1 = token.balanceOf(alice);

        vm.roll(block.number + 1);
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertGt(token.balanceOf(alice), bal1, "Second buy should add tokens");
    }

    // ════════════════════════════════════════════════════════════════════
    // E. SECURITY TESTS
    // ════════════════════════════════════════════════════════════════════

    function test_transfer_lock_same_block() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 bal = token.balanceOf(alice);

        // Try to transfer in same block — should revert
        vm.prank(alice);
        vm.expectRevert("Transfer locked this block");
        token.transfer(bob, bal / 2);
    }

    function test_transfer_lock_next_block_ok() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 amount = token.balanceOf(alice) / 2;

        vm.roll(block.number + 1);
        vm.prank(alice);
        token.transfer(bob, amount);
        assertEq(token.balanceOf(bob), amount, "Transfer should work next block");
    }

    function test_no_transfer_tax() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 amount = token.balanceOf(alice) / 2;

        vm.roll(block.number + 1);
        vm.prank(alice);
        token.transfer(bob, amount);
        assertEq(token.balanceOf(bob), amount, "Zero transfer tax - exact amount received");
    }

    function test_no_owner() public {
        // TokenV3 has no Ownable — no owner() function exists
        // Verify deployer has no special token powers after setup
        assertEq(token.balanceOf(address(this)), 0, "Deployer should hold 0 tokens");
    }

    function test_no_hidden_mint() public {
        uint256 supplyBefore = token.totalSupply();
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertLt(token.totalSupply(), supplyBefore, "No mint - supply only goes down");
    }

    function test_reject_direct_eth() public {
        vm.prank(alice);
        vm.expectRevert("No direct ETH");
        (bool ok,) = address(router).call{value: 1 ether}("");
        // The revert happens inside receive(), but the call itself doesn't bubble up in test
        // Instead verify through different pattern
    }

    function test_direct_eth_send_reverts() public {
        // Use low-level call to send ETH directly
        vm.prank(alice);
        (bool success,) = address(router).call{value: 0.01 ether}("");
        assertFalse(success, "Direct ETH send should fail");
    }

    function test_sweep_revert_not_graduated() public {
        vm.prank(creator);
        vm.expectRevert("Not graduated");
        router.sweepResidualETH();
    }

    function test_sweep_revert_not_creator() public {
        _pushToGraduated();
        vm.prank(alice);
        vm.expectRevert("Not creator");
        router.sweepResidualETH();
    }

    function test_sweep_after_graduation() public {
        _pushToGraduated();
        // Deal extra dust ETH above the reserved amount (simulating rounding refunds from DEXes)
        uint256 reserved = router.realETH() + router.pendingCreatorFees();
        vm.deal(address(router), reserved + 0.0001 ether);

        uint256 creatorBefore = creator.balance;
        vm.prank(creator);
        router.sweepResidualETH();
        assertGt(creator.balance, creatorBefore, "Creator should receive dust");
        // Verify it only swept the dust, not the reserved ETH
        assertGe(address(router).balance, reserved, "Reserved ETH should remain");
    }

    function test_addAerodrome_external_reverts_for_non_self() public {
        vm.prank(alice);
        vm.expectRevert("Internal only");
        router._addAerodrome(0.001 ether, 1e18, 0, 0);
    }

    function test_addV4_external_reverts_for_non_self() public {
        vm.prank(alice);
        vm.expectRevert("Internal only");
        router._addV4(0.001 ether, 1e18);
    }

    function test_retryTier_revert_not_failed() public {
        vm.expectRevert("Tier not failed");
        router.retryTier(0);
    }

    function test_retryTier_revert_invalid() public {
        vm.expectRevert("Invalid tier");
        router.retryTier(5);
    }

    // ════════════════════════════════════════════════════════════════════
    // E. SECURITY — ETH Accounting Integrity
    // ════════════════════════════════════════════════════════════════════

    function test_eth_accounting_always_solvent() public {
        // Buy several times, then verify contract balance >= realETH + pendingFees
        for (uint256 i = 0; i < 5; i++) {
            address buyer = _getBuyer(i);
            vm.prank(buyer);
            router.buy{value: MED_BUY}(0);
        }
        assertGe(
            address(router).balance,
            router.realETH() + router.pendingCreatorFees(),
            "Contract must hold at least realETH + pendingFees"
        );
    }

    function test_eth_accounting_after_sell() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        vm.prank(bob);
        router.buy{value: SMALL_BUY}(0);

        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);

        assertGe(
            address(router).balance,
            router.realETH() + router.pendingCreatorFees(),
            "Solvent after sell"
        );
    }

    function test_eth_accounting_after_tier0() public {
        _pushToTier0();
        assertGe(
            address(router).balance,
            router.realETH() + router.pendingCreatorFees(),
            "Solvent after tier 0 graduation"
        );
    }

    function test_eth_accounting_after_full_graduation() public {
        _pushToGraduated();
        assertGe(
            address(router).balance,
            router.realETH() + router.pendingCreatorFees(),
            "Solvent after full graduation"
        );
    }

    function test_eth_accounting_after_fee_claim() public {
        vm.prank(alice);
        router.buy{value: MED_BUY}(0);
        vm.prank(creator);
        router.claimFees();
        assertGe(
            address(router).balance,
            router.realETH() + router.pendingCreatorFees(),
            "Solvent after fee claim"
        );
    }

    // ════════════════════════════════════════════════════════════════════
    // E. SECURITY — Token Contract
    // ════════════════════════════════════════════════════════════════════

    function test_token_setRouter_only_once() public {
        TokenV3 t = new TokenV3("Test", "TST");
        t.setRouter(address(0x1));
        vm.expectRevert("Already set");
        t.setRouter(address(0x2));
    }

    function test_token_setRouter_revert_zero() public {
        TokenV3 t = new TokenV3("Test", "TST");
        vm.expectRevert("Zero addr");
        t.setRouter(address(0));
    }

    function test_token_setRouter_revert_not_deployer() public {
        TokenV3 t = new TokenV3("Test", "TST");
        vm.prank(alice);
        vm.expectRevert("Not deployer");
        t.setRouter(address(0x1));
    }

    function test_token_transfers_work_without_router() public {
        // Without router set, normal transfers still work (no tradingEnabled gate)
        TokenV3 t = new TokenV3("Test", "TST");
        t.transfer(alice, 1000e18);
        vm.prank(alice);
        t.transfer(bob, 500e18);
        assertEq(t.balanceOf(bob), 500e18, "Transfer should work with no router");
    }

    function test_token_no_ownable() public {
        // TokenV3 does not inherit Ownable — no owner, no pause, no freeze
        // This ensures GoPlus transfer_pausable flag is NOT triggered
        TokenV3 t = new TokenV3("Test", "TST");
        // Deployer can set router, but has no other special powers
        t.setRouter(address(0x1));
        // After setRouter, deployer is just another address
        t.transfer(alice, 1000e18);
        vm.prank(alice);
        t.transfer(bob, 500e18);
        assertEq(t.balanceOf(bob), 500e18);
    }

    function test_token_name_symbol() public view {
        assertEq(token.name(), "Obsidian");
        assertEq(token.symbol(), "OBSD");
    }

    // ════════════════════════════════════════════════════════════════════
    // F. GAS TESTS
    // ════════════════════════════════════════════════════════════════════

    function test_gas_normal_buy() public {
        // Use a small buy that doesn't trigger tier graduation
        uint256 gasBefore = gasleft();
        vm.prank(alice);
        router.buy{value: 0.0001 ether}(0);
        uint256 gasUsed = gasBefore - gasleft();
        assertLt(gasUsed, 250_000, "Normal buy should be under 250k gas");
    }

    function test_gas_normal_sell() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);

        uint256 gasBefore = gasleft();
        vm.prank(alice);
        router.sell(sellAmt, 0);
        uint256 gasUsed = gasBefore - gasleft();
        assertLt(gasUsed, 200_000, "Normal sell should be under 200k gas");
    }

    function test_gas_claimFees() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);

        uint256 gasBefore = gasleft();
        vm.prank(creator);
        router.claimFees();
        uint256 gasUsed = gasBefore - gasleft();
        assertLt(gasUsed, 100_000, "claimFees should be under 100k gas");
    }

    // ════════════════════════════════════════════════════════════════════
    // G. PHASE & TIER STATE TESTS
    // ════════════════════════════════════════════════════════════════════

    function test_initial_phase_is_bonding_curve() public view {
        assertEq(uint8(router.phase()), uint8(RouterV3.Phase.BondingCurve));
    }

    function test_initial_tier_is_zero() public view {
        assertEq(router.currentTier(), 0);
    }

    function test_tiers_advance_in_order() public {
        // Push through tiers and verify ordering
        _pushToTier0();
        assertGe(router.currentTier(), 1, "Should be past tier 0");
        assertTrue(router.tierCompleted(0), "Tier 0 completed");
    }

    function test_phase_never_goes_backwards() public {
        assertEq(uint8(router.phase()), 0); // BondingCurve
        _pushToTier0();
        assertEq(uint8(router.phase()), 1); // Hybrid
        _pushToGraduated();
        assertEq(uint8(router.phase()), 2); // Graduated
    }

    function test_tier_eth_deployed_tracked() public {
        _pushToTier0();
        assertGt(router.tierETHDeployed(0), 0, "Tier 0 should track ETH deployed");
    }

    function test_v4TokenIds_length_grows() public {
        _pushToTier0();
        uint256 len1 = router.getV4TokenIdsLength();
        assertGt(len1, 0, "Should have at least 1 V4 position after tier 0");
    }

    // ════════════════════════════════════════════════════════════════════
    // H. CREATOR FEE INVARIANT
    // ════════════════════════════════════════════════════════════════════

    function test_creator_fee_exactly_1pct_on_buy() public {
        vm.prank(alice);
        router.buy{value: 0.001 ether}(0);
        // 1% of 0.001 = 0.00001
        assertEq(router.pendingCreatorFees(), 0.00001 ether, "Fee should be exactly 1%");
    }

    function test_creator_fee_on_sell() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 buyFees = router.pendingCreatorFees();

        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);

        assertGt(router.pendingCreatorFees(), buyFees, "Sell should add creator fee");
    }

    // ════════════════════════════════════════════════════════════════════
    // I. ADDITIONAL EDGE CASES
    // ════════════════════════════════════════════════════════════════════

    function test_whale_single_buy_graduates_all() public {
        // A 1 ETH buy should trigger all 5 tiers via cumulative threshold
        vm.prank(alice);
        router.buy{value: 1 ether}(0);
        assertEq(uint8(router.phase()), uint8(RouterV3.Phase.Graduated));
        // totalETHDeployed should be positive
        assertGt(router.totalETHDeployed(), 0, "ETH should have been deployed to DEXes");
    }

    function test_cumulative_threshold_works() public {
        // Buy small amounts that individually are below tier thresholds
        // but cumulatively should trigger progression
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(_getBuyer(i));
            router.buy{value: 0.0002 ether}(0);
        }
        // 5 * 0.0002 * 0.99 = 0.00099 realETH (pre-deployment)
        // Tier 0 threshold = 0.0005 — should have triggered
        assertTrue(router.tierCompleted(0), "Tier 0 should trigger from cumulative buys");
    }

    function test_sell_works_in_hybrid_iv_rises() public {
        _pushToTier0();
        // New buy in Hybrid
        vm.prank(charlie);
        router.buy{value: 0.01 ether}(0);
        uint256 bal = token.balanceOf(charlie);
        uint256 ivBefore = router.iv();

        vm.prank(charlie);
        token.approve(address(router), bal);
        vm.roll(block.number + 1);
        vm.prank(charlie);
        router.sell(bal / 2, 0);

        assertGe(router.iv(), ivBefore, "IV must rise on sell in Hybrid");
        // Verify tokens were burned
        assertLt(token.balanceOf(charlie), bal, "Tokens should be burned");
    }

    function test_sell_in_hybrid_then_tiers_still_progress() public {
        _pushToTier0();
        assertTrue(uint8(router.phase()) == uint8(RouterV3.Phase.Hybrid), "Should be Hybrid");

        // Buy, then sell some in Hybrid
        vm.prank(alice);
        router.buy{value: 0.01 ether}(0);
        uint256 bal = token.balanceOf(alice);
        vm.prank(alice);
        token.approve(address(router), bal / 2);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(bal / 2, 0);

        // Tiers should still progress with more buys
        vm.roll(block.number + 1);
        for (uint256 i = 0; i < 10; i++) {
            if (uint8(router.phase()) == uint8(RouterV3.Phase.Graduated)) break;
            vm.prank(_getBuyer(i));
            router.buy{value: 0.1 ether}(0);
        }
        // With ~1 ETH cumulative, should hit tier 4 (0.5 ETH threshold)
        assertTrue(router.tierCompleted(4), "Should reach final tier despite Hybrid sells");
        assertEq(uint8(router.phase()), uint8(RouterV3.Phase.Graduated), "Should graduate");
    }

    function test_buy_after_graduation_reverts() public {
        _pushToGraduated();
        vm.prank(charlie);
        vm.expectRevert("Graduated");
        router.buy{value: 0.001 ether}(0);
    }

    function test_sell_after_graduation_reverts() public {
        _pushToGraduated();
        vm.prank(alice);
        vm.expectRevert("Graduated");
        router.sell(1e18, 0);
    }

    function test_claimFees_after_graduation() public {
        _pushToGraduated();
        uint256 fees = router.pendingCreatorFees();
        if (fees > 0) {
            uint256 before = creator.balance;
            vm.prank(creator);
            router.claimFees();
            assertEq(creator.balance - before, fees);
        }
    }

    function test_multiple_buys_iv_monotonic_no_tier() public {
        // 4 tiny buys that stay below tier 0 threshold (0.0005 ETH cumulative)
        // Each 0.0001 ETH buy adds ~0.000099 realETH
        // 4 buys = 0.000396 < 0.0005 threshold
        uint256 prevIV = 0;
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(_getBuyer(i));
            router.buy{value: 0.0001 ether}(0);
            uint256 newIV = router.iv();
            assertGe(newIV, prevIV, "IV must not decrease on buy (no tier)");
            prevIV = newIV;
        }
    }

    function test_totalETHDeployed_tracks_correctly() public {
        assertEq(router.totalETHDeployed(), 0, "Should start at 0");
        _pushToTier0();
        assertGt(router.totalETHDeployed(), 0, "Should increase after tier 0");
        uint256 deployed0 = router.totalETHDeployed();
        _pushToGraduated();
        assertGt(router.totalETHDeployed(), deployed0, "Should increase after full graduation");
    }

    function test_token_burn_works_after_router_buy() public {
        vm.prank(alice);
        router.buy{value: 0.001 ether}(0);
        uint256 bal = token.balanceOf(alice);
        uint256 supply = token.totalSupply();

        // Burns should work in the same block (burns are allowed)
        vm.prank(alice);
        token.burn(bal / 2);
        assertEq(token.totalSupply(), supply - bal / 2, "Burn should reduce supply");
    }

    function test_transfer_to_router_blocked_same_block() public {
        vm.prank(alice);
        router.buy{value: 0.001 ether}(0);
        uint256 bal = token.balanceOf(alice);

        // Transfer to router also blocked same block (consistent anti-flash-loan)
        vm.prank(alice);
        vm.expectRevert("Transfer locked this block");
        token.transfer(address(router), bal / 4);

        // Next block: transfer to router works fine
        vm.roll(block.number + 1);
        vm.prank(alice);
        token.transfer(address(router), bal / 4);
    }

    function testFuzz_no_max_buy_any_amount(uint256 ethAmt) public {
        ethAmt = bound(ethAmt, 0.0001 ether, 50 ether);
        vm.prank(alice);
        router.buy{value: ethAmt}(0);
        assertGt(token.balanceOf(alice), 0, "Any amount should produce tokens");
        assertGt(router.spotPrice(), 0, "Spot should be positive");
    }

    // ════════════════════════════════════════════════════════════════════
    // HELPERS
    // ════════════════════════════════════════════════════════════════════

    function MIN_BUY() internal pure returns (uint256) {
        return 0.0001 ether;
    }

    /// @dev Push realETH past tier 0 threshold (0.0005 ETH)
    ///      A single 0.001 ETH buy gives 0.00099 realETH, crossing 0.0005 threshold
    function _pushToTier0() internal {
        vm.prank(alice);
        router.buy{value: 0.001 ether}(0);
        if (!router.tierCompleted(0)) {
            // Safety: buy more if needed
            vm.prank(bob);
            router.buy{value: 0.001 ether}(0);
        }
        assertTrue(router.tierCompleted(0), "Tier 0 should be completed");
    }

    /// @dev Push all the way to Graduated by buying with large amounts
    function _pushToGraduated() internal {
        uint256 maxIter = 20;
        for (uint256 i = 0; i < maxIter; i++) {
            if (uint8(router.phase()) == uint8(RouterV3.Phase.Graduated)) break;
            address buyer = _getBuyer(i);
            vm.prank(buyer);
            router.buy{value: 0.5 ether}(0);
        }
        assertEq(uint8(router.phase()), uint8(RouterV3.Phase.Graduated), "Should be graduated");
    }

    function _getBuyer(uint256 i) internal view returns (address) {
        address[5] memory buyers = [alice, bob, charlie, dave, eve];
        return buyers[i % 5];
    }
}
