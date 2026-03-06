// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {TokenV3} from "../src/TokenV3.sol";
import {RouterV3} from "../src/RouterV3.sol";

contract DeployV3Script is Script {
    address constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant V4_POSITION_MANAGER = 0x7C5f5A4bBd8fD63184577525326123B519429bDc;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function run() external {
        address creator = 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334;
        uint256 initialVirtualETH = 0.5 ether;

        // Read token name and symbol from env vars, with defaults
        string memory defaultName = "Obsidian";
        string memory defaultSymbol = "OBSD";
        string memory tokenName = vm.envOr("TOKEN_NAME", defaultName);
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", defaultSymbol);

        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);

        // Deploy TokenV3 with name and symbol from env vars
        TokenV3 token = new TokenV3(tokenName, tokenSymbol);
        console.log("TokenV3:", address(token));
        console.log("Token Name:", tokenName);
        console.log("Token Symbol:", tokenSymbol);

        // Deploy RouterV3 with all required parameters
        RouterV3 router = new RouterV3(
            address(token),
            creator,
            AERODROME_ROUTER,
            V4_POSITION_MANAGER,
            PERMIT2,
            initialVirtualETH
        );
        console.log("RouterV3:", address(router));

        // Set router on token
        token.setRouter(address(router));

        // Transfer ALL tokens from deployer to router — deployer keeps ZERO
        uint256 bal = token.balanceOf(deployer);
        require(bal == 1_000_000_000e18, "Bad balance");
        token.transfer(address(router), bal);
        require(token.balanceOf(deployer) == 0, "Deployer not empty");
        require(token.balanceOf(address(router)) == bal, "Router not loaded");

        // No enableTrading() or renounceOwnership() needed — TokenV3 has no Ownable.
        // Router is set, deployer has 0 tokens, deployer has no special powers.

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Deployer:", deployer);
        console.log("Creator:", creator);
        console.log("Token Balance (router):", bal);
        console.log("Initial Virtual ETH:", initialVirtualETH);
        console.log("Status: Router set. Deployer holds 0 tokens. No owner.");

        vm.stopBroadcast();
    }
}
