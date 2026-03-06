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

/// @notice Launch a token via LaunchPad — used by GitHub Actions deploy bot
/// Env vars:
///   THRYXTREASURY_PRIVATE_KEY — deployer private key
///   TOKEN_NAME     — token name (e.g. "Degen Ape")
///   TOKEN_SYMBOL   — token symbol (e.g. "DAPE")
///   CREATOR_PAYOUT — 0x address that receives OBSD earnings
contract LaunchTokenScript is Script {
    address constant LAUNCHPAD = 0xFD8F5C2DAb7C5F2954ba43c0ae85BF94601C06C1;
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;

    uint256 constant DEFAULT_SUPPLY = 1_000_000_000e18; // 1 billion
    uint256 constant DEFAULT_OBSD_SEED = 100e18;        // 100 OBSD
    uint256 constant DEFAULT_POOL_PERCENT = 80;          // 80% to pool, 20% to creator

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        string memory name = vm.envString("TOKEN_NAME");
        string memory symbol = vm.envString("TOKEN_SYMBOL");
        address payout = vm.envAddress("CREATOR_PAYOUT");

        vm.startBroadcast(deployerKey);

        // Approve OBSD spend for pool seeding
        IERC20(OBSD).approve(LAUNCHPAD, DEFAULT_OBSD_SEED);

        // Launch
        (address token, address pool) = ILaunchPad(LAUNCHPAD).launch(
            name,
            symbol,
            DEFAULT_SUPPLY,
            DEFAULT_OBSD_SEED,
            DEFAULT_POOL_PERCENT,
            payout
        );

        vm.stopBroadcast();

        // These lines are parsed by the GitHub Action
        console.log("token=%s", token);
        console.log("pool=%s", pool);
        console.log("name=%s", name);
        console.log("symbol=%s", symbol);
    }
}
