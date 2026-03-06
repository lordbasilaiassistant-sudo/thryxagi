// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {OBSDPairFactory} from "../src/OBSDPairFactory.sol";

/// @notice Deploy the OBSDPairFactory contract
/// Usage:
///   forge script script/DeployFactory.s.sol --rpc-url https://mainnet.base.org --broadcast
contract DeployFactoryScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");

        address obsd = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;
        address aeroRouter = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43; // Aerodrome Router v2

        vm.startBroadcast(deployerKey);
        OBSDPairFactory factory = new OBSDPairFactory(obsd, aeroRouter);
        vm.stopBroadcast();

        console.log("OBSDPairFactory deployed:", address(factory));
        console.log("OBSD:", obsd);
        console.log("Aero Router:", aeroRouter);
    }
}
