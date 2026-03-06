// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {OBSDPairFactory} from "../src/OBSDPairFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Launch a new child token paired with OBSD via the factory
/// Usage:
///   FACTORY=0x... TOKEN_NAME="Moon Dog" TOKEN_SYMBOL="MDOG" TOKEN_SUPPLY=1000000000000000000000000000 \
///   OBSD_SEED=100000000000000000000000 POOL_PERCENT=80 \
///   forge script script/LaunchChild.s.sol --rpc-url https://mainnet.base.org --broadcast
contract LaunchChildScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address factory = vm.envAddress("FACTORY");
        string memory name = vm.envString("TOKEN_NAME");
        string memory symbol = vm.envString("TOKEN_SYMBOL");
        uint256 supply = vm.envUint("TOKEN_SUPPLY");
        uint256 obsdSeed = vm.envUint("OBSD_SEED");
        uint256 poolPercent = vm.envUint("POOL_PERCENT");

        address obsd = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;

        console.log("Launching:", name, symbol);
        console.log("Supply:", supply);
        console.log("OBSD seed:", obsdSeed);
        console.log("Pool %:", poolPercent);

        vm.startBroadcast(deployerKey);

        // Approve factory to spend our OBSD
        IERC20(obsd).approve(factory, obsdSeed);

        // Launch!
        (address token, address pool) = OBSDPairFactory(factory).launch(
            name,
            symbol,
            supply,
            obsdSeed,
            poolPercent
        );

        vm.stopBroadcast();

        console.log("Token deployed:", token);
        console.log("Aero pool:", pool);
        console.log("LP tokens sent to deployer (you earn swap fees)");
    }
}
