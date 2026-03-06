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
    function defaultFactory() external view returns (address);
}

contract MicroBuyScript is Script {
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;

    function run() external {
        uint256 buyAmount = vm.envOr("BUY_AMOUNT", uint256(0.00004 ether));
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address factory = IAeroRouter(AERO_ROUTER).defaultFactory();

        IAeroRouter.Route[] memory route = new IAeroRouter.Route[](1);
        route[0] = IAeroRouter.Route({from: WETH, to: OBSD, stable: false, factory: factory});

        console.log("MicroBuy:", buyAmount, "ETH");
        vm.startBroadcast(deployerKey);
        IAeroRouter(AERO_ROUTER).swapExactETHForTokens{value: buyAmount}(0, route, deployer, block.timestamp + 300);
        vm.stopBroadcast();
        console.log("Done. Wallet:", deployer.balance);
    }
}
