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

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract AeroVolumeScript is Script {
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address factory = IAeroRouter(AERO_ROUTER).defaultFactory();

        IAeroRouter.Route[] memory buyRoute = new IAeroRouter.Route[](1);
        buyRoute[0] = IAeroRouter.Route({from: WETH, to: OBSD, stable: false, factory: factory});

        IAeroRouter.Route[] memory sellRoute = new IAeroRouter.Route[](1);
        sellRoute[0] = IAeroRouter.Route({from: OBSD, to: WETH, stable: false, factory: factory});

        console.log("=== AERO VOLUME WAVE ===");
        console.log("Wallet:", deployer.balance);

        vm.startBroadcast(deployerKey);

        // Buy 1
        IAeroRouter(AERO_ROUTER).swapExactETHForTokens{value: 0.00008 ether}(0, buyRoute, deployer, block.timestamp + 300);
        console.log("Buy 1: 0.00008 ETH");

        // Approve for sells
        IERC20(OBSD).approve(AERO_ROUTER, type(uint256).max);

        // Sell back small amount
        uint256 sellAmt = IERC20(OBSD).balanceOf(deployer) / 20;
        IAeroRouter(AERO_ROUTER).swapExactTokensForETH(sellAmt, 0, sellRoute, deployer, block.timestamp + 300);
        console.log("Sell 1: 5% of balance");

        // Buy 2
        IAeroRouter(AERO_ROUTER).swapExactETHForTokens{value: 0.00006 ether}(0, buyRoute, deployer, block.timestamp + 300);
        console.log("Buy 2: 0.00006 ETH");

        // Buy 3
        IAeroRouter(AERO_ROUTER).swapExactETHForTokens{value: 0.00005 ether}(0, buyRoute, deployer, block.timestamp + 300);
        console.log("Buy 3: 0.00005 ETH");

        vm.stopBroadcast();

        console.log("=== VOLUME WAVE COMPLETE ===");
        console.log("Wallet after:", deployer.balance);
        console.log("OBSD balance:", IERC20(OBSD).balanceOf(deployer));
    }
}
