// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {FeeAggregator} from "../src/FeeAggregator.sol";

contract DeployFeeAggregator is Script {
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant STAKING_VAULT = 0xA2E0295d07d9D03B51b122a0C307054fE69e31C2;

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        FeeAggregator agg = new FeeAggregator(OBSD, AERO_ROUTER, STAKING_VAULT);
        console.log("FeeAggregator deployed:", address(agg));

        vm.stopBroadcast();
    }
}
