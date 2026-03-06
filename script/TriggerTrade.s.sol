// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

interface IChildRouter {
    function buyWithETH(address childToken, uint256 minChildOut) external payable;
    function quoteETHToChild(address childToken, uint256 ethAmount) external view returns (uint256);
}

/// @notice Trigger a minimal trade on a child token via ChildRouter to index on DexScreener
/// Usage:
///   CHILD_TOKEN=0x... forge script script/TriggerTrade.s.sol --rpc-url https://mainnet.base.org --broadcast
///   Or use defaults (WORK token):
///   forge script script/TriggerTrade.s.sol --rpc-url https://mainnet.base.org --broadcast
contract TriggerTradeScript is Script {
    address constant CHILD_ROUTER = 0xCb7a49CE25093f06028003D51aBc47fBE32875de;
    address constant WORK_TOKEN = 0x9Ac4dd1252Dc8C5d3a17bDaAd2576Ec3CcFd8a72;

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address childToken = vm.envOr("CHILD_TOKEN", WORK_TOKEN);
        uint256 buyAmount = vm.envOr("BUY_AMOUNT", uint256(0.00001 ether));

        console.log("=== TRIGGER TRADE ===");
        console.log("ChildRouter:", CHILD_ROUTER);
        console.log("Child token:", childToken);
        console.log("Buy amount (ETH):", buyAmount);
        console.log("Buyer:", deployer);

        // Quote expected output
        try IChildRouter(CHILD_ROUTER).quoteETHToChild(childToken, buyAmount) returns (uint256 expectedOut) {
            console.log("Expected child tokens out:", expectedOut);
        } catch {
            console.log("Quote failed - pool may lack liquidity");
        }

        vm.startBroadcast(deployerKey);
        IChildRouter(CHILD_ROUTER).buyWithETH{value: buyAmount}(childToken, 0);
        vm.stopBroadcast();

        console.log("=== TRADE COMPLETE ===");
        console.log("DexScreener should index the pool after this trade.");
    }
}
