// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {OBSDPairFactory} from "../src/OBSDPairFactory.sol";
import {ChildToken} from "../src/ChildToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Fork test against Base mainnet — verifies factory deploys and seeds pools
contract FactoryTest is Test {
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant DEPLOYER = 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334;

    OBSDPairFactory factory;

    function setUp() public {
        vm.createSelectFork("https://mainnet.base.org");

        vm.startPrank(DEPLOYER);
        factory = new OBSDPairFactory(OBSD, AERO_ROUTER);
        vm.stopPrank();
    }

    function test_factory_deploys() public view {
        assertEq(factory.obsd(), OBSD);
        assertEq(factory.aeroRouter(), AERO_ROUTER);
        assertEq(factory.owner(), DEPLOYER);
        assertEq(factory.totalLaunches(), 0);
    }

    function test_launch_child_token() public {
        uint256 supply = 1_000_000_000e18;
        uint256 obsdSeed = 100_000e18; // 100k OBSD
        uint256 poolPercent = 80;

        // Check deployer has enough OBSD
        uint256 deployerObsd = IERC20(OBSD).balanceOf(DEPLOYER);
        assertGt(deployerObsd, obsdSeed, "Deployer needs OBSD");

        vm.startPrank(DEPLOYER);

        // Approve factory to spend OBSD
        IERC20(OBSD).approve(address(factory), obsdSeed);

        // Launch
        (address token, address pool) = factory.launch(
            "Test Meme",
            "TMEME",
            supply,
            obsdSeed,
            poolPercent
        );

        vm.stopPrank();

        // Verify token deployed
        assertTrue(token != address(0), "Token should be deployed");
        assertEq(IERC20(token).totalSupply(), supply, "Supply should match");

        // Verify deployer got 20% of tokens (100% - 80% pool)
        uint256 deployerTokens = IERC20(token).balanceOf(DEPLOYER);
        assertEq(deployerTokens, supply * 20 / 100, "Deployer should get 20%");

        // Verify pool was created
        assertTrue(pool != address(0), "Pool should exist");

        // Verify launch recorded
        assertEq(factory.totalLaunches(), 1);

        (address recToken, address recPool, string memory name,,,,) = factory.launches(0);
        assertEq(recToken, token);
        assertEq(recPool, pool);
        assertEq(keccak256(bytes(name)), keccak256(bytes("Test Meme")));
    }

    function test_only_owner_can_launch() public {
        address rando = makeAddr("rando");
        vm.startPrank(rando);

        vm.expectRevert("Only owner");
        factory.launch("Bad", "BAD", 1e18, 1e18, 50);

        vm.stopPrank();
    }

    function test_multiple_launches() public {
        uint256 obsdSeed = 50_000e18;

        vm.startPrank(DEPLOYER);
        IERC20(OBSD).approve(address(factory), obsdSeed * 3);

        factory.launch("Alpha", "ALPHA", 1e27, obsdSeed, 90);
        factory.launch("Beta", "BETA", 1e27, obsdSeed, 90);
        factory.launch("Gamma", "GAMMA", 1e27, obsdSeed, 90);

        vm.stopPrank();

        assertEq(factory.totalLaunches(), 3);
    }
}
