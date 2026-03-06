// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

interface ICreatorTokenV2 {
    function distribute() external;
    function pendingFees() external view returns (uint256);
    function backingVault() external view returns (uint256);
    function totalOBSDToCreator() external view returns (uint256);
    function totalOBSDToTreasury() external view returns (uint256);
    function iv() external view returns (uint256);
    function circulating() external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract DistributeOGEN is Script {
    address constant OGEN = 0x195264611494C8B83F11A98b442Af9d2C5F5B66b;
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;
    address constant DEPLOYER = 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334;

    function run() external {
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");

        ICreatorTokenV2 ogen = ICreatorTokenV2(OGEN);

        // Pre state
        console.log("=== PRE-DISTRIBUTE ===");
        console.log("pendingFees:", ogen.pendingFees());
        console.log("backingVault:", ogen.backingVault());
        console.log("totalOBSDToCreator:", ogen.totalOBSDToCreator());
        console.log("totalOBSDToTreasury:", ogen.totalOBSDToTreasury());
        console.log("iv:", ogen.iv());
        console.log("OBSD balance (deployer):", IERC20(OBSD).balanceOf(DEPLOYER));

        vm.startBroadcast(deployerKey);
        ogen.distribute();
        vm.stopBroadcast();

        // Post state
        console.log("=== POST-DISTRIBUTE ===");
        console.log("pendingFees:", ogen.pendingFees());
        console.log("backingVault:", ogen.backingVault());
        console.log("totalOBSDToCreator:", ogen.totalOBSDToCreator());
        console.log("totalOBSDToTreasury:", ogen.totalOBSDToTreasury());
        console.log("iv:", ogen.iv());
        console.log("OBSD balance (deployer):", IERC20(OBSD).balanceOf(DEPLOYER));
    }
}
