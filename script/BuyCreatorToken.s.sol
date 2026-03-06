// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPlatformRouter {
    function buyWithETH(address childToken, uint256 minOut) external payable;
}

interface ICreatorTokenV2 {
    function iv() external view returns (uint256);
    function circulating() external view returns (uint256);
    function backingVault() external view returns (uint256);
    function totalBurned() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalOBSDToCreator() external view returns (uint256);
    function totalOBSDToTreasury() external view returns (uint256);
    function pendingFees() external view returns (uint256);
    function pool() external view returns (address);
}

/// @notice Buy a CreatorToken via PlatformRouter (ETH-in)
/// Usage:
///   TOKEN=0x... BUY_AMOUNT=100000000000000 forge script script/BuyCreatorToken.s.sol --rpc-url https://mainnet.base.org --broadcast
contract BuyCreatorTokenScript is Script {
    address constant PLATFORM_ROUTER = 0x29b41D0FaE0ac1491001909E340D0BA58B28A701;
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address token = vm.envAddress("TOKEN");
        uint256 buyAmount = vm.envOr("BUY_AMOUNT", uint256(0.0001 ether));

        ICreatorTokenV2 ct = ICreatorTokenV2(token);

        console.log("=== PRE-BUY STATE ===");
        console.log("Token:", token);
        console.log("Buyer:", deployer);
        console.log("Buy ETH:", buyAmount);
        console.log("totalSupply:", ct.totalSupply());
        console.log("totalBurned:", ct.totalBurned());
        console.log("circulating:", ct.circulating());
        console.log("iv:", ct.iv());
        console.log("backingVault:", ct.backingVault());
        console.log("pendingFees:", ct.pendingFees());
        console.log("OBSD to creator:", ct.totalOBSDToCreator());
        console.log("Token balance:", IERC20(token).balanceOf(deployer));
        console.log("OBSD balance:", IERC20(OBSD).balanceOf(deployer));

        vm.startBroadcast(deployerKey);
        IPlatformRouter(PLATFORM_ROUTER).buyWithETH{value: buyAmount}(token, 0);
        vm.stopBroadcast();

        console.log("=== POST-BUY STATE ===");
        console.log("totalSupply:", ct.totalSupply());
        console.log("totalBurned:", ct.totalBurned());
        console.log("circulating:", ct.circulating());
        console.log("iv:", ct.iv());
        console.log("backingVault:", ct.backingVault());
        console.log("pendingFees:", ct.pendingFees());
        console.log("OBSD to creator:", ct.totalOBSDToCreator());
        console.log("Token balance:", IERC20(token).balanceOf(deployer));
        console.log("OBSD balance:", IERC20(OBSD).balanceOf(deployer));
    }
}
