// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {EverRise} from "../src/EverRise.sol";

contract DeployScript is Script {
    function run() external {
        address creator = 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334;
        uint256 initialVirtualETH = 1 ether; // conservative config

        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        EverRise token = new EverRise(creator, initialVirtualETH);

        console.log("EverRise deployed at:", address(token));
        console.log("Creator:", creator);
        console.log("vETH:", token.vETH());
        console.log("k:", token.k());

        vm.stopBroadcast();
    }
}
