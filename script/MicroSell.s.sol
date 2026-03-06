// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }
    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, Route[] calldata routes, address to, uint256 deadline) external returns (uint256[] memory);
    function defaultFactory() external view returns (address);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract MicroSellScript is Script {
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;

    function run() external {
        uint256 sellPct = vm.envOr("SELL_PCT", uint256(10)); // default 10% of balance
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address factory = IAeroRouter(AERO_ROUTER).defaultFactory();

        uint256 bal = IERC20(OBSD).balanceOf(deployer);
        uint256 sellAmt = bal * sellPct / 100;
        require(sellAmt > 0, "Nothing to sell");

        IAeroRouter.Route[] memory route = new IAeroRouter.Route[](1);
        route[0] = IAeroRouter.Route({from: OBSD, to: WETH, stable: false, factory: factory});

        console.log("MicroSell:", sellAmt);
        vm.startBroadcast(deployerKey);
        IERC20(OBSD).approve(AERO_ROUTER, sellAmt);
        IAeroRouter(AERO_ROUTER).swapExactTokensForETH(sellAmt, 0, route, deployer, block.timestamp + 300);
        vm.stopBroadcast();
        console.log("Done. Wallet:", deployer.balance);
    }
}
