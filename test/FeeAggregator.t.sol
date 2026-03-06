// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {FeeAggregator} from "../src/FeeAggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// --- Mock contracts ---

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract MockAeroRouter {
    address public immutable factoryAddr;

    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    constructor(address factory_) { factoryAddr = factory_; }

    function defaultFactory() external view returns (address) { return factoryAddr; }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        Route[] calldata routes,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        // Simulate swap: transfer tokenIn from caller, mint tokenOut to recipient
        // For testing: 1:1 swap ratio
        address tokenIn = routes[0].from;
        address tokenOut = routes[routes.length - 1].to;

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        MockERC20(tokenOut).mint(to, amountIn);

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }
}

contract MockAeroPool {
    address public token0;
    address public token1;
    uint256 public fee0;
    uint256 public fee1;

    constructor(address t0, address t1) {
        token0 = t0;
        token1 = t1;
    }

    function setFees(uint256 f0, uint256 f1) external {
        fee0 = f0;
        fee1 = f1;
    }

    function claimFees() external returns (uint256 claimed0, uint256 claimed1) {
        claimed0 = fee0;
        claimed1 = fee1;
        fee0 = 0;
        fee1 = 0;

        // Transfer tokens to caller (simulating fee claim)
        if (claimed0 > 0) IERC20(token0).transfer(msg.sender, claimed0);
        if (claimed1 > 0) IERC20(token1).transfer(msg.sender, claimed1);
    }
}

// --- Tests ---

contract FeeAggregatorTest is Test {
    FeeAggregator aggregator;
    MockERC20 obsd;
    MockERC20 tokenA;
    MockAeroRouter router;
    MockAeroPool pool;
    address vault = makeAddr("vault");
    address notOwner = makeAddr("notOwner");

    function setUp() public {
        obsd = new MockERC20("OBSD", "OBSD");
        tokenA = new MockERC20("TokenA", "TKA");
        router = new MockAeroRouter(makeAddr("factory"));
        aggregator = new FeeAggregator(address(obsd), address(router), vault);

        pool = new MockAeroPool(address(tokenA), address(obsd));
    }

    // ===== addPool =====

    function test_addPool() public {
        aggregator.addPool(address(pool));

        assertTrue(aggregator.isTracked(address(pool)));
        assertEq(aggregator.poolCount(), 1);
        assertEq(aggregator.pools(0), address(pool));
    }

    function test_addPool_emitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit FeeAggregator.PoolAdded(address(pool));
        aggregator.addPool(address(pool));
    }

    function test_addPool_revertNotOwner() public {
        vm.prank(notOwner);
        vm.expectRevert("Not owner");
        aggregator.addPool(address(pool));
    }

    function test_addPool_revertAlreadyTracked() public {
        aggregator.addPool(address(pool));
        vm.expectRevert("Already tracked");
        aggregator.addPool(address(pool));
    }

    function test_addPool_revertZeroAddress() public {
        vm.expectRevert("Zero address");
        aggregator.addPool(address(0));
    }

    // ===== removePool =====

    function test_removePool() public {
        aggregator.addPool(address(pool));
        aggregator.removePool(address(pool));

        assertFalse(aggregator.isTracked(address(pool)));
        assertEq(aggregator.poolCount(), 0);
    }

    function test_removePool_emitsEvent() public {
        aggregator.addPool(address(pool));

        vm.expectEmit(true, false, false, false);
        emit FeeAggregator.PoolRemoved(address(pool));
        aggregator.removePool(address(pool));
    }

    function test_removePool_revertNotTracked() public {
        vm.expectRevert("Not tracked");
        aggregator.removePool(address(pool));
    }

    function test_removePool_swapAndPop() public {
        MockAeroPool pool2 = new MockAeroPool(address(tokenA), address(obsd));
        MockAeroPool pool3 = new MockAeroPool(address(tokenA), address(obsd));

        aggregator.addPool(address(pool));
        aggregator.addPool(address(pool2));
        aggregator.addPool(address(pool3));

        // Remove middle pool — should swap with last
        aggregator.removePool(address(pool2));
        assertEq(aggregator.poolCount(), 2);
        assertEq(aggregator.pools(0), address(pool));
        assertEq(aggregator.pools(1), address(pool3));
    }

    // ===== harvestPool =====

    function test_harvestPool_obsdFees() public {
        aggregator.addPool(address(pool));

        // Pool has OBSD fees (token1 = obsd)
        obsd.mint(address(pool), 1000e18);
        pool.setFees(0, 1000e18);

        uint256 result = aggregator.harvestPool(address(pool));

        // OBSD goes straight to vault, no swap
        assertEq(result, 1000e18);
        assertEq(obsd.balanceOf(vault), 1000e18);
    }

    function test_harvestPool_nonObsdFees() public {
        aggregator.addPool(address(pool));

        // Pool has tokenA fees (token0 = tokenA)
        tokenA.mint(address(pool), 500e18);
        pool.setFees(500e18, 0);

        uint256 result = aggregator.harvestPool(address(pool));

        // tokenA swapped 1:1 to OBSD (mock), sent to vault
        assertEq(result, 500e18);
        assertEq(obsd.balanceOf(vault), 500e18);
    }

    function test_harvestPool_bothFees() public {
        aggregator.addPool(address(pool));

        tokenA.mint(address(pool), 300e18);
        obsd.mint(address(pool), 200e18);
        pool.setFees(300e18, 200e18);

        uint256 result = aggregator.harvestPool(address(pool));

        assertEq(result, 500e18); // 300 swapped + 200 direct
        assertEq(obsd.balanceOf(vault), 500e18);
    }

    function test_harvestPool_zeroFees() public {
        aggregator.addPool(address(pool));
        pool.setFees(0, 0);

        uint256 result = aggregator.harvestPool(address(pool));
        assertEq(result, 0);
        assertEq(obsd.balanceOf(vault), 0);
    }

    function test_harvestPool_emitsEvent() public {
        aggregator.addPool(address(pool));
        obsd.mint(address(pool), 100e18);
        pool.setFees(0, 100e18);

        vm.expectEmit(true, false, false, true);
        emit FeeAggregator.FeesHarvested(address(pool), 100e18);
        aggregator.harvestPool(address(pool));
    }

    function test_harvestPool_revertNotTracked() public {
        vm.expectRevert("Not tracked");
        aggregator.harvestPool(address(pool));
    }

    // ===== harvestAll =====

    function test_harvestAll() public {
        MockAeroPool pool2 = new MockAeroPool(address(tokenA), address(obsd));

        aggregator.addPool(address(pool));
        aggregator.addPool(address(pool2));

        obsd.mint(address(pool), 100e18);
        pool.setFees(0, 100e18);

        obsd.mint(address(pool2), 200e18);
        pool2.setFees(0, 200e18);

        uint256 total = aggregator.harvestAll();
        assertEq(total, 300e18);
        assertEq(obsd.balanceOf(vault), 300e18);
    }

    function test_harvestAll_empty() public {
        uint256 total = aggregator.harvestAll();
        assertEq(total, 0);
    }

    // ===== getPools =====

    function test_getPools() public {
        aggregator.addPool(address(pool));

        address[] memory result = aggregator.getPools();
        assertEq(result.length, 1);
        assertEq(result[0], address(pool));
    }

    // ===== setStakingVault =====

    function test_setStakingVault() public {
        address newVault = makeAddr("newVault");
        aggregator.setStakingVault(newVault);
        assertEq(aggregator.stakingVault(), newVault);
    }

    function test_setStakingVault_revertNotOwner() public {
        vm.prank(notOwner);
        vm.expectRevert("Not owner");
        aggregator.setStakingVault(makeAddr("x"));
    }

    // ===== harvestPool with no vault =====

    function test_harvestPool_noVault_keepsFunds() public {
        // Create aggregator with no vault
        FeeAggregator agg2 = new FeeAggregator(address(obsd), address(router), address(0));
        MockAeroPool pool2 = new MockAeroPool(address(tokenA), address(obsd));

        agg2.addPool(address(pool2));
        obsd.mint(address(pool2), 100e18);
        pool2.setFees(0, 100e18);

        uint256 result = agg2.harvestPool(address(pool2));
        assertEq(result, 100e18);
        // OBSD stays in aggregator since vault is address(0)
        assertEq(obsd.balanceOf(address(agg2)), 100e18);
    }

    // ===== transferOwnership =====

    function test_transferOwnership() public {
        aggregator.transferOwnership(notOwner);
        assertEq(aggregator.owner(), notOwner);
    }

    function test_transferOwnership_revertZero() public {
        vm.expectRevert("Zero address");
        aggregator.transferOwnership(address(0));
    }

    // ===== rescue =====

    function test_rescue() public {
        obsd.mint(address(aggregator), 50e18);
        address recipient = makeAddr("recipient");

        aggregator.rescue(address(obsd), 50e18, recipient);
        assertEq(obsd.balanceOf(recipient), 50e18);
    }

    function test_rescue_revertNotOwner() public {
        vm.prank(notOwner);
        vm.expectRevert("Not owner");
        aggregator.rescue(address(obsd), 1, notOwner);
    }

    // ===== Constructor =====

    function test_constructor_revertZeroObsd() public {
        vm.expectRevert("Zero address");
        new FeeAggregator(address(0), address(router), vault);
    }

    function test_constructor_revertZeroRouter() public {
        vm.expectRevert("Zero address");
        new FeeAggregator(address(obsd), address(0), vault);
    }
}
