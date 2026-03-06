// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BasaltToken} from "../src/EverRiseToken.sol";
import {BasaltRouter} from "../src/EverRiseRouter.sol";

contract DeployV2Script is Script {
    address constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant V4_POSITION_MANAGER = 0x7C5f5A4bBd8fD63184577525326123B519429bDc;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function run() external {
        address creator = 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334;
        uint256 initialVirtualETH = 0.5 ether;

        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);

        BasaltToken token = new BasaltToken();
        console.log("Token:", address(token));

        BasaltRouter router = new BasaltRouter(
            address(token), creator, AERODROME_ROUTER, V4_POSITION_MANAGER, PERMIT2, initialVirtualETH
        );
        console.log("Router:", address(router));

        token.setRouter(address(router));

        // Transfer ALL tokens to router — deployer keeps ZERO
        uint256 bal = token.balanceOf(deployer);
        require(bal == 1_000_000_000e18, "Bad balance");
        token.transfer(address(router), bal);
        require(token.balanceOf(deployer) == 0, "Deployer not empty");
        require(token.balanceOf(address(router)) == bal, "Router not loaded");

        token.enableTrading();
        token.renounceOwnership();

        console.log("BASALT live. 0 deployer tokens. Graduation at 2 ETH.");
        vm.stopBroadcast();
    }
}
