// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {StakingVault} from "../src/StakingVault.sol";

contract DeployStakingVault is Script {
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        StakingVault vault = new StakingVault(OBSD);
        console.log("StakingVault deployed:", address(vault));

        vm.stopBroadcast();
    }
}
