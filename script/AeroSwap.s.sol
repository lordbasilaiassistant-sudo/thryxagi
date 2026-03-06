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

    function swapExactETHForTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function defaultFactory() external view returns (address);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract AeroSwapScript is Script {
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;

    function run() external {
        uint256 swapAmount = vm.envOr("SWAP_AMOUNT", uint256(0.0001 ether));
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address factory = IAeroRouter(AERO_ROUTER).defaultFactory();

        uint256 obsdBefore = IERC20(OBSD).balanceOf(deployer);
        console.log("=== AERODROME DIRECT SWAP ===");
        console.log("Swap amount:", swapAmount);
        console.log("OBSD balance before:", obsdBefore);
        console.log("Factory:", factory);

        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({
            from: WETH,
            to: OBSD,
            stable: false,
            factory: factory
        });

        vm.startBroadcast(deployerKey);
        uint256[] memory amounts = IAeroRouter(AERO_ROUTER).swapExactETHForTokens{value: swapAmount}(
            0, // minOut = 0 for tiny swap
            routes,
            deployer,
            block.timestamp + 300
        );
        vm.stopBroadcast();

        uint256 obsdAfter = IERC20(OBSD).balanceOf(deployer);
        console.log("=== SWAP COMPLETE ===");
        console.log("OBSD received:", obsdAfter - obsdBefore);
        console.log("OBSD balance after:", obsdAfter);
        console.log("DexScreener should now index the Aerodrome pool!");
    }
}
