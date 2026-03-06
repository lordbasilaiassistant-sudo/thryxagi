// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IChildRouter {
    function sellForETH(address childToken, uint256 childAmount, uint256 minETHOut) external;
    function quoteChildToETH(address childToken, uint256 childAmount) external view returns (uint256);
}

/// @notice Sell a child token for ETH via ChildRouter
/// Usage:
///   CHILD_TOKEN=0x... SELL_AMOUNT=1000000000000000000000 \
///   forge script script/SellChild.s.sol --rpc-url https://mainnet.base.org --broadcast
contract SellChildScript is Script {
    address constant CHILD_ROUTER = 0xCb7a49CE25093f06028003D51aBc47fBE32875de;

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address childToken = vm.envAddress("CHILD_TOKEN");
        uint256 sellAmount = vm.envUint("SELL_AMOUNT");

        console.log("Selling child token:", childToken);
        console.log("Amount (wei):", sellAmount);

        // Quote expected ETH output
        try IChildRouter(CHILD_ROUTER).quoteChildToETH(childToken, sellAmount) returns (uint256 expectedETH) {
            console.log("Expected ETH out:", expectedETH);
        } catch {
            console.log("Quote failed - proceeding anyway");
        }

        vm.startBroadcast(deployerKey);

        // Approve ChildRouter to spend tokens
        IERC20(childToken).approve(CHILD_ROUTER, sellAmount);

        // Sell
        IChildRouter(CHILD_ROUTER).sellForETH(childToken, sellAmount, 0);

        vm.stopBroadcast();

        console.log("Sell complete.");
    }
}
