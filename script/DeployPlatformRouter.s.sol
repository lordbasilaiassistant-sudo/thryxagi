// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {PlatformRouter} from "../src/PlatformRouter.sol";

/// @notice Deploy the PlatformRouter — ETH-in/ETH-out with 0.5% auto ETH fee
/// Usage:
///   forge script script/DeployPlatformRouter.s.sol --rpc-url https://mainnet.base.org --broadcast
contract DeployPlatformRouterScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");

        address obsd = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;
        address weth = 0x4200000000000000000000000000000000000006;
        address aeroRouter = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
        address treasury = 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334;

        vm.startBroadcast(deployerKey);
        PlatformRouter router = new PlatformRouter(obsd, weth, aeroRouter, treasury);
        vm.stopBroadcast();

        console.log("PlatformRouter deployed:", address(router));
    }
}
