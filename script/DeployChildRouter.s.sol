// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {ChildRouter} from "../src/ChildRouter.sol";

/// @notice Deploy the ChildRouter — ETH-in/ETH-out meta-router for child tokens
/// Usage:
///   forge script script/DeployChildRouter.s.sol --rpc-url https://mainnet.base.org --broadcast
contract DeployChildRouterScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");

        address obsdToken = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;
        address weth = 0x4200000000000000000000000000000000000006;
        address aeroRouter = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;

        vm.startBroadcast(deployerKey);
        ChildRouter router = new ChildRouter(obsdToken, weth, aeroRouter);
        vm.stopBroadcast();

        console.log("ChildRouter deployed:", address(router));
        console.log("OBSD Token:", obsdToken);
        console.log("WETH:", weth);
        console.log("Aero Router:", aeroRouter);
    }
}
