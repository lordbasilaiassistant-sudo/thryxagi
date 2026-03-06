// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ChildRouter} from "../src/ChildRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Fork test — verifies ChildRouter multi-hop ETH→WETH→OBSD→Child swaps
contract ChildRouterTest is Test {
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant DEPLOYER = 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334;

    // WORK token — first child token deployed via factory
    address constant WORK = 0x9Ac4dd1252Dc8C5d3a17bDaAd2576Ec3CcFd8a72;

    // OBSD/WETH Aero pool must exist for multi-hop to work
    address constant OBSD_WETH_POOL = 0x5c1db3247c989eA36Cfd1dd435ed3085287b52ac;

    ChildRouter router;

    function setUp() public {
        vm.createSelectFork("https://mainnet.base.org");

        vm.startPrank(DEPLOYER);
        router = new ChildRouter(OBSD, WETH, AERO_ROUTER);
        vm.stopPrank();
    }

    function test_router_deploys() public view {
        assertEq(router.obsdToken(), OBSD);
        assertEq(router.weth(), WETH);
        assertEq(router.aeroRouter(), AERO_ROUTER);
        assertEq(router.owner(), DEPLOYER);
    }

    function test_buy_child_with_eth() public {
        address buyer = makeAddr("buyer");
        vm.deal(buyer, 0.0001 ether);

        vm.startPrank(buyer);
        uint256 workBefore = IERC20(WORK).balanceOf(buyer);
        router.buyWithETH{value: 0.0001 ether}(WORK, 0);
        uint256 workAfter = IERC20(WORK).balanceOf(buyer);
        vm.stopPrank();

        assertGt(workAfter, workBefore, "Buyer should receive WORK tokens");
        assertEq(buyer.balance, 0, "All ETH should be spent");
    }

    function test_sell_child_for_eth() public {
        address trader = makeAddr("trader");
        vm.deal(trader, 0.0001 ether);

        vm.startPrank(trader);
        // Buy first
        router.buyWithETH{value: 0.0001 ether}(WORK, 0);
        uint256 workBalance = IERC20(WORK).balanceOf(trader);
        assertGt(workBalance, 0, "Should have WORK after buy");

        // Sell half
        uint256 sellAmount = workBalance / 2;
        IERC20(WORK).approve(address(router), sellAmount);

        uint256 ethBefore = trader.balance;
        router.sellForETH(WORK, sellAmount, 0);
        uint256 ethAfter = trader.balance;
        vm.stopPrank();

        assertGt(ethAfter, ethBefore, "Should receive ETH from sell");
    }

    function test_quote_functions() public view {
        uint256 childOut = router.quoteETHToChild(WORK, 0.0001 ether);
        // May be 0 if pool has no WETH/OBSD liquidity path, but shouldn't revert
        // With live pools, should return > 0
        assertGt(childOut, 0, "Quote should return tokens");
    }

    function test_only_owner_can_recover() public {
        address rando = makeAddr("rando");
        vm.startPrank(rando);
        vm.expectRevert("Only owner");
        router.recover(WORK, 1e18);
        vm.expectRevert("Only owner");
        router.recoverETH();
        vm.stopPrank();
    }
}
