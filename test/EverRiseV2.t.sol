// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BasaltToken} from "../src/EverRiseToken.sol";
import {BasaltRouter, PoolKey} from "../src/EverRiseRouter.sol";

// ── Mocks ──

contract MockAeroPool {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockAeroFactory {
    mapping(bytes32 => address) internal pools;
    function getPool(address a, address b, bool stable) external view returns (address) { return pools[_k(a, b, stable)]; }
    function createPool(address a, address b, bool stable) external returns (address) {
        bytes32 key = _k(a, b, stable);
        if (pools[key] == address(0)) pools[key] = address(new MockAeroPool());
        return pools[key];
    }
    function _k(address a, address b, bool s) internal pure returns (bytes32) {
        (address t0, address t1) = a < b ? (a, b) : (b, a);
        return keccak256(abi.encodePacked(t0, t1, s));
    }
}

contract MockAeroRouter {
    MockAeroFactory public mockFactory;
    address public constant WETH_ADDR = 0x4200000000000000000000000000000000000006;
    constructor() { mockFactory = new MockAeroFactory(); }
    function defaultFactory() external view returns (address) { return address(mockFactory); }
    function weth() external pure returns (address) { return WETH_ADDR; }
    function poolFor(address a, address b, bool stable, address) external view returns (address) { return mockFactory.getPool(a, b, stable); }
    function addLiquidityETH(address tkn, bool stable, uint256 amt, uint256, uint256, address to, uint256)
        external payable returns (uint256, uint256, uint256)
    {
        IERC20(tkn).transferFrom(msg.sender, address(this), amt);
        address pool = mockFactory.createPool(tkn, WETH_ADDR, stable);
        MockAeroPool(pool).mint(to, msg.value);
        return (amt, msg.value, msg.value);
    }
}

contract MockV4PositionManager {
    uint256 private _nextId = 1;
    mapping(uint256 => address) public ownerOf;
    function nextTokenId() external view returns (uint256) { return _nextId; }
    function initializePool(PoolKey calldata, uint160) external payable returns (int24) { return 0; }
    function modifyLiquidities(bytes calldata, uint256) external payable { ownerOf[_nextId] = msg.sender; _nextId++; }
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

contract MockPermit2 { function approve(address, address, uint160, uint48) external {} }

// ── Tests ──
// GRADUATION_ETH = 0.001 ether, MAX_BUY = 0.005 ether
// Non-graduation tests use 0.0003 ETH buys (net ~0.000297, stays below 0.001 grad threshold)
// Graduation tests use 0.001 ETH buys (net ~0.00099, two buys trigger graduation)

contract BasaltV2Test is Test {
    BasaltToken public token;
    BasaltRouter public router;
    MockAeroRouter public mockAero;
    MockV4PositionManager public mockV4;
    MockPermit2 public mockPermit2;

    address public creator = address(0xC0FFEE);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public charlie = address(0xC4A4);
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // Small buy that won't trigger graduation (net ~0.000297 < 0.001 threshold)
    uint256 constant SMALL_BUY = 0.0003 ether;
    // Buy that gets close to graduation
    uint256 constant MED_BUY = 0.0005 ether;

    function setUp() public {
        mockAero = new MockAeroRouter();
        mockV4 = new MockV4PositionManager();
        mockPermit2 = new MockPermit2();
        token = new BasaltToken();
        router = new BasaltRouter(
            address(token), creator, address(mockAero), address(mockV4), address(mockPermit2), 0.5 ether
        );
        token.setRouter(address(router));
        token.transfer(address(router), token.balanceOf(address(this)));
        token.enableTrading();
        token.renounceOwnership();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    // ── Basic ──

    function test_buy_basic() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertGt(token.balanceOf(alice), 0);
        assertGt(router.realETH(), 0);
        assertGt(router.iv(), 0);
        assertGt(creator.balance, 0);
    }

    function test_sell_after_buy() public {
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
        assertLt(token.balanceOf(alice), bal);
        assertGt(alice.balance, ethBefore);
    }

    // ── IV Invariant ──

    function test_iv_never_decreases_on_buy() public {
        vm.prank(alice);
        router.buy{value: 0.0002 ether}(0);
        uint256 iv1 = router.iv();
        vm.prank(bob);
        router.buy{value: 0.0002 ether}(0);
        assertGe(router.iv(), iv1);
        uint256 iv2 = router.iv();
        vm.prank(charlie);
        router.buy{value: 0.0002 ether}(0);
        assertGe(router.iv(), iv2);
    }

    function test_iv_never_decreases_on_sell() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        vm.roll(block.number + 1);
        vm.prank(bob);
        router.buy{value: SMALL_BUY}(0);
        uint256 ivBefore = router.iv();
        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertGt(router.iv(), ivBefore);
    }

    function test_iv_stress_many_trades() public {
        address[5] memory traders = [alice, bob, charlie, address(0xD0D), address(0xE0E)];
        for (uint256 i = 3; i < 5; i++) vm.deal(traders[i], 10 ether);

        // Small buys that don't trigger graduation
        for (uint256 i = 0; i < 10; i++) {
            address t = traders[i % 5];
            uint256 ivBefore = router.iv();
            vm.prank(t);
            router.buy{value: 0.0001 ether}(0);
            assertGe(router.iv(), ivBefore);
            if (router.graduated()) break;
        }
        if (router.graduated()) return;

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
            assertGe(router.iv(), ivBefore);
        }
    }

    // ── Spot Price ──

    function test_spot_only_increases() public {
        uint256 spot1 = router.spotPrice();
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertGt(router.spotPrice(), spot1);

        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        uint256 spotBefore = router.spotPrice();
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertEq(router.spotPrice(), spotBefore);
    }

    // ── Graduation ──

    function test_dual_graduation_triggers() public {
        _graduateRouter();
        assertTrue(router.graduated());
        assertEq(router.realETH(), 0);
        assertTrue(router.aeroPool() != address(0));
        assertGt(router.v4TokenId(), 0);
    }

    function test_aero_lp_burned() public {
        _graduateRouter();
        address poolAddr = router.aeroPool();
        assertGt(MockAeroPool(poolAddr).balanceOf(DEAD), 0);
        assertEq(MockAeroPool(poolAddr).balanceOf(address(router)), 0);
    }

    function test_v4_nft_burned() public {
        _graduateRouter();
        uint256 tokenId = router.v4TokenId();
        assertEq(mockV4.ownerOf(tokenId), DEAD);
    }

    function test_post_graduation_disabled() public {
        _graduateRouter();
        vm.prank(alice);
        vm.expectRevert("Graduated");
        router.buy{value: 0.0001 ether}(0);
    }

    function test_aero_uses_volatile_pool() public {
        _graduateRouter();
        address weth = mockAero.weth();
        MockAeroFactory factory = MockAeroFactory(mockAero.mockFactory());
        assertEq(router.aeroPool(), factory.getPool(address(token), weth, false));
    }

    // ── Bot Safety ──

    function test_no_transfer_tax() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 amount = token.balanceOf(alice) / 2;
        vm.prank(alice);
        token.transfer(bob, amount);
        assertEq(token.balanceOf(bob), amount);
    }

    function test_ownership_renounced() public view {
        assertEq(token.owner(), address(0));
    }

    function test_no_hidden_mint() public {
        uint256 before = token.totalSupply();
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertLt(token.totalSupply(), before);
    }

    // ── Security ──

    function test_revert_sameBlockSell() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        vm.prank(alice);
        token.approve(address(router), 1e18);
        vm.prank(alice);
        vm.expectRevert("Same block");
        router.sell(1e18, 0);
    }

    function test_revert_belowMinBuy() public {
        vm.prank(alice);
        vm.expectRevert("Below min");
        router.buy{value: 0.00001 ether}(0);
    }

    function test_revert_aboveMaxBuy() public {
        vm.prank(alice);
        vm.expectRevert("Above max");
        router.buy{value: 0.01 ether}(0);
    }

    function test_slippage_buy() public {
        vm.prank(alice);
        vm.expectRevert("Slippage");
        router.buy{value: 0.0002 ether}(type(uint256).max);
    }

    function test_slippage_sell() public {
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

    // ── Creator Earnings ──

    function test_creator_earns_on_buy() public {
        uint256 before = creator.balance;
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertGt(creator.balance, before); // 1% fee
    }

    function test_creator_earns_on_sell() public {
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        uint256 creatorBefore = creator.balance;
        uint256 sellAmt = token.balanceOf(alice) / 4;
        vm.prank(alice);
        token.approve(address(router), sellAmt);
        vm.roll(block.number + 1);
        vm.prank(alice);
        router.sell(sellAmt, 0);
        assertGt(creator.balance, creatorBefore);
    }

    // ── Estimates ──

    function test_estimateBuy() public {
        (uint256 est,) = router.estimateBuy(SMALL_BUY);
        vm.prank(alice);
        router.buy{value: SMALL_BUY}(0);
        assertEq(token.balanceOf(alice), est);
    }

    function test_estimateSell() public {
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
        assertEq(alice.balance - ethBefore, est);
    }

    // ── Helper ──

    function _graduateRouter() internal {
        // Two buys to exceed 0.001 ETH graduation threshold
        vm.prank(alice);
        router.buy{value: 0.001 ether}(0);
        if (!router.graduated()) {
            vm.prank(bob);
            router.buy{value: 0.001 ether}(0);
        }
        assertTrue(router.graduated());
    }
}
