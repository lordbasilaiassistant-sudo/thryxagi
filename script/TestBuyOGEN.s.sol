// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

interface IPlatformRouter {
    function buyWithETH(address token, uint256 minOut) external payable;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
}

contract TestBuyOGEN is Script {
    address constant PLATFORM_ROUTER = 0x29b41D0FaE0ac1491001909E340D0BA58B28A701;
    address constant OGEN = 0x195264611494C8B83F11A98b442Af9d2C5F5B66b;
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // Pre-buy state
        uint256 ogenBefore = IERC20(OGEN).balanceOf(deployer);
        uint256 obsdBefore = IERC20(OBSD).balanceOf(deployer);
        uint256 ethBefore = deployer.balance;
        uint256 supplyBefore = IERC20(OGEN).totalSupply();

        console.log("=== PRE-BUY STATE ===");
        console.log("ETH balance:", ethBefore);
        console.log("OGEN balance:", ogenBefore);
        console.log("OBSD balance:", obsdBefore);
        console.log("OGEN total supply:", supplyBefore);

        // Buy 0.0001 ETH worth of OGEN (~$0.20)
        vm.startBroadcast(deployerKey);
        IPlatformRouter(PLATFORM_ROUTER).buyWithETH{value: 0.0001 ether}(OGEN, 0);
        vm.stopBroadcast();

        // Post-buy state
        uint256 ogenAfter = IERC20(OGEN).balanceOf(deployer);
        uint256 obsdAfter = IERC20(OBSD).balanceOf(deployer);
        uint256 ethAfter = deployer.balance;
        uint256 supplyAfter = IERC20(OGEN).totalSupply();

        console.log("=== POST-BUY STATE ===");
        console.log("ETH spent:", ethBefore - ethAfter);
        console.log("OGEN received:", ogenAfter - ogenBefore);
        console.log("OBSD earned (creator fee):", obsdAfter - obsdBefore);
        console.log("OGEN burned (supply reduction):", supplyBefore - supplyAfter);
        console.log("New OGEN supply:", supplyAfter);
    }
}
