// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }
    function swapExactETHForTokens(uint256 amountOutMin, Route[] calldata routes, address to, uint256 deadline) external payable returns (uint256[] memory);
    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, Route[] calldata routes, address to, uint256 deadline) external returns (uint256[] memory);
    function defaultFactory() external view returns (address);
}

interface IRouter {
    function buy(uint256 minTokensOut) external payable;
    function sell(uint256 tokenAmount, uint256 minETHOut) external;
    function realETH() external view returns (uint256);
    function circulating() external view returns (uint256);
    function totalETHDeployed() external view returns (uint256);
    function phase() external view returns (uint8);
    function currentTier() external view returns (uint8);
    function pendingCreatorFees() external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract BlitzScript is Script {
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;
    address constant ROUTER = 0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E;

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address factory = IAeroRouter(AERO_ROUTER).defaultFactory();

        uint256 realETHBefore = IRouter(ROUTER).realETH();
        uint256 circBefore = IRouter(ROUTER).circulating();
        uint256 ivBefore = circBefore > 0 ? (realETHBefore * 1e18) / circBefore : 0;

        console.log("=== BLITZ START ===");
        console.log("Wallet ETH:", deployer.balance);
        console.log("realETH:", realETHBefore);
        console.log("Circulating:", circBefore);
        console.log("IV (x1e18):", ivBefore);
        console.log("Phase:", IRouter(ROUTER).phase());

        IAeroRouter.Route[] memory buyRoute = new IAeroRouter.Route[](1);
        buyRoute[0] = IAeroRouter.Route({from: WETH, to: OBSD, stable: false, factory: factory});

        IAeroRouter.Route[] memory sellRoute = new IAeroRouter.Route[](1);
        sellRoute[0] = IAeroRouter.Route({from: OBSD, to: WETH, stable: false, factory: factory});

        vm.startBroadcast(deployerKey);

        // === WAVE 1: Aerodrome buy-sell cycles to build DexScreener volume ===
        // Buy on Aero
        IAeroRouter(AERO_ROUTER).swapExactETHForTokens{value: 0.00008 ether}(0, buyRoute, deployer, block.timestamp + 300);
        console.log("Aero buy 1 done");

        // Approve and sell small amount back on Aero (creates 2-way volume)
        IERC20(OBSD).approve(AERO_ROUTER, type(uint256).max);
        uint256 sellAmt1 = IERC20(OBSD).balanceOf(deployer) / 20; // sell 5%
        if (sellAmt1 > 0) {
            IAeroRouter(AERO_ROUTER).swapExactTokensForETH(sellAmt1, 0, sellRoute, deployer, block.timestamp + 300);
            console.log("Aero sell 1 done");
        }

        // Buy again on Aero
        IAeroRouter(AERO_ROUTER).swapExactETHForTokens{value: 0.00006 ether}(0, buyRoute, deployer, block.timestamp + 300);
        console.log("Aero buy 2 done");

        // === WAVE 2: Router buy to push toward Tier 1 ===
        IRouter(ROUTER).buy{value: 0.0003 ether}(0);
        console.log("Router buy done");

        // === WAVE 3: Small router sell to demonstrate IV rising on-chain ===
        // Approve router
        IERC20(OBSD).approve(ROUTER, type(uint256).max);
        // Sell a small portion — this proves IV mechanism works
        uint256 sellAmt2 = IRouter(ROUTER).circulating() / 100; // sell 1% of circulating
        uint256 myBal = IERC20(OBSD).balanceOf(deployer);
        if (sellAmt2 > myBal) sellAmt2 = myBal / 20;
        if (sellAmt2 > 1e18) {
            IRouter(ROUTER).sell(sellAmt2, 0);
            console.log("Router sell done - IV should rise");
        }

        // === WAVE 4: One more Aero swap for volume ===
        IAeroRouter(AERO_ROUTER).swapExactETHForTokens{value: 0.00005 ether}(0, buyRoute, deployer, block.timestamp + 300);
        console.log("Aero buy 3 done");

        vm.stopBroadcast();

        // === REPORT ===
        uint256 realETHAfter = IRouter(ROUTER).realETH();
        uint256 circAfter = IRouter(ROUTER).circulating();
        uint256 ivAfter = circAfter > 0 ? (realETHAfter * 1e18) / circAfter : 0;
        uint256 cumulative = realETHAfter + IRouter(ROUTER).totalETHDeployed();

        console.log("=== BLITZ COMPLETE ===");
        console.log("Wallet ETH:", deployer.balance);
        console.log("realETH:", realETHAfter);
        console.log("Circulating:", circAfter);
        console.log("IV (x1e18):", ivAfter);
        console.log("IV increased:", ivAfter > ivBefore);
        console.log("Cumulative ETH:", cumulative);
        console.log("Tier 1 threshold: 5000000000000000");
        console.log("Gap to Tier 1:", cumulative >= 5000000000000000 ? 0 : 5000000000000000 - cumulative);
        console.log("Phase:", IRouter(ROUTER).phase());
        console.log("Pending fees:", IRouter(ROUTER).pendingCreatorFees());
    }
}
