// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PayrollScript is Script {
    function run() external {
        address token = vm.envAddress("OBSD_TOKEN");
        address recipient = vm.envAddress("PAYROLL_RECIPIENT");
        uint256 amount = vm.envUint("PAYROLL_AMOUNT");
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");

        address deployer = vm.addr(deployerKey);
        uint256 balance = IERC20(token).balanceOf(deployer);

        console.log("=== OBSD Payroll ===");
        console.log("From:", deployer);
        console.log("To:", recipient);
        console.log("Amount:", amount);
        console.log("Balance:", balance);

        require(balance >= amount, "Insufficient OBSD balance for payroll");

        vm.startBroadcast(deployerKey);
        IERC20(token).transfer(recipient, amount);
        vm.stopBroadcast();

        console.log("Transfer complete.");
    }
}
