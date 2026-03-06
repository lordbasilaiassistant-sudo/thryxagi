// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ReferralRegistry} from "../src/ReferralRegistry.sol";

contract DeployReferralRegistry is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        ReferralRegistry registry = new ReferralRegistry();
        console.log("ReferralRegistry deployed:", address(registry));

        vm.stopBroadcast();
    }
}
