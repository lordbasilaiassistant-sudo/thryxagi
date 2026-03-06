// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

interface IRouter {
    function buy(uint256 minTokensOut) external payable;
    function phase() external view returns (uint8);
    function realETH() external view returns (uint256);
    function circulating() external view returns (uint256);
    function pendingCreatorFees() external view returns (uint256);
    function totalETHDeployed() external view returns (uint256);
    function currentTier() external view returns (uint8);
}

contract BuyScript is Script {
    function run() external {
        address router = 0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E;
        uint256 buyAmount = vm.envOr("BUY_AMOUNT", uint256(0.002 ether));

        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("=== PRE-BUY STATE ===");
        console.log("Buyer:", deployer);
        console.log("Buy amount:", buyAmount);
        console.log("Phase:", IRouter(router).phase());
        console.log("realETH:", IRouter(router).realETH());
        console.log("Circulating:", IRouter(router).circulating());
        console.log("ETH Deployed:", IRouter(router).totalETHDeployed());

        vm.startBroadcast(deployerKey);
        IRouter(router).buy{value: buyAmount}(0);
        vm.stopBroadcast();

        console.log("=== POST-BUY STATE ===");
        console.log("Phase:", IRouter(router).phase());
        console.log("realETH:", IRouter(router).realETH());
        console.log("Circulating:", IRouter(router).circulating());
        console.log("Pending Fees:", IRouter(router).pendingCreatorFees());
        console.log("ETH Deployed:", IRouter(router).totalETHDeployed());
        console.log("Current Tier:", IRouter(router).currentTier());
    }
}
