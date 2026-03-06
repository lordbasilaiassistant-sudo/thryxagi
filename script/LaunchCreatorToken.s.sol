// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILaunchPad {
    function launch(
        string calldata name_,
        string calldata symbol_,
        uint256 supply_,
        uint256 obsdSeed_,
        uint256 poolPercent_,
        address creatorPayout_
    ) external returns (address token, address pool);
}

/// @notice Launch a CreatorToken through the live LaunchPad
/// Usage:
///   TOKEN_NAME="Degen Ape" TOKEN_SYMBOL="DAPE" CREATOR_PAYOUT=0x... \
///   forge script script/LaunchCreatorToken.s.sol --rpc-url https://mainnet.base.org --broadcast
///
/// Optional env vars:
///   OBSD_SEED     — OBSD to seed pool (default: 10000e18)
///   POOL_PERCENT  — % of supply for pool (default: 80)
contract LaunchCreatorTokenScript is Script {
    address constant LAUNCHPAD = 0xFD8F5C2DAb7C5F2954ba43c0ae85BF94601C06C1;
    address constant OBSD      = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;

    uint256 constant DEFAULT_SUPPLY       = 1_000_000_000e18; // 1 billion
    uint256 constant DEFAULT_OBSD_SEED    = 10_000e18;        // 10K OBSD
    uint256 constant DEFAULT_POOL_PERCENT = 80;               // 80% to pool

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        string memory name = vm.envString("TOKEN_NAME");
        string memory symbol = vm.envString("TOKEN_SYMBOL");
        address payout = vm.envAddress("CREATOR_PAYOUT");

        uint256 obsdSeed = vm.envOr("OBSD_SEED", DEFAULT_OBSD_SEED);
        uint256 poolPercent = vm.envOr("POOL_PERCENT", DEFAULT_POOL_PERCENT);

        console.log("=== LaunchCreatorToken ===");
        console.log("LaunchPad:", LAUNCHPAD);
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Payout:", payout);
        console.log("OBSD seed:", obsdSeed);
        console.log("Pool %:", poolPercent);

        vm.startBroadcast(deployerKey);

        // Approve LaunchPad to spend OBSD for pool seeding
        IERC20(OBSD).approve(LAUNCHPAD, obsdSeed);

        // Launch token + pool
        (address token, address pool) = ILaunchPad(LAUNCHPAD).launch(
            name,
            symbol,
            DEFAULT_SUPPLY,
            obsdSeed,
            poolPercent,
            payout
        );

        vm.stopBroadcast();

        console.log("=== Deployed ===");
        console.log("token=%s", token);
        console.log("pool=%s", pool);
        console.log("Creator payout:", payout);
    }
}
