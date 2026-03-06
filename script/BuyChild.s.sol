// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

interface IChildRouter {
    function buyWithETH(address childToken, uint256 minChildOut) external payable;
    function quoteETHToChild(address childToken, uint256 ethAmount) external view returns (uint256);
}

/// @notice Buy a child token with ETH via ChildRouter
/// Usage:
///   CHILD_TOKEN=0x... BUY_AMOUNT=100000000000000 \
///   forge script script/BuyChild.s.sol --rpc-url https://mainnet.base.org --broadcast
contract BuyChildScript is Script {
    address constant CHILD_ROUTER = 0xCb7a49CE25093f06028003D51aBc47fBE32875de;

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address childToken = vm.envAddress("CHILD_TOKEN");
        uint256 buyAmount = vm.envUint("BUY_AMOUNT");

        console.log("Buying child token:", childToken);
        console.log("ETH amount (wei):", buyAmount);

        // Quote expected output
        try IChildRouter(CHILD_ROUTER).quoteETHToChild(childToken, buyAmount) returns (uint256 expectedOut) {
            console.log("Expected tokens out:", expectedOut);
        } catch {
            console.log("Quote failed - proceeding anyway");
        }

        vm.startBroadcast(deployerKey);
        IChildRouter(CHILD_ROUTER).buyWithETH{value: buyAmount}(childToken, 0);
        vm.stopBroadcast();

        console.log("Buy complete.");
    }
}
