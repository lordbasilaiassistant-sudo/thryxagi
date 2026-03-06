// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {LaunchPad} from "../src/LaunchPad.sol";
import {CreatorTokenV2} from "../src/CreatorTokenV2.sol";
import {PlatformRouter} from "../src/PlatformRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Fork test — verifies LaunchPad + CreatorTokenV2 + PlatformRouter full flow
contract LaunchPadTest is Test {
    address constant OBSD = 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant DEPLOYER = 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334;

    LaunchPad pad;
    PlatformRouter router;

    function setUp() public {
        vm.createSelectFork("https://mainnet.base.org");

        vm.startPrank(DEPLOYER);
        pad = new LaunchPad(OBSD, AERO_ROUTER, DEPLOYER);
        router = new PlatformRouter(OBSD, WETH, AERO_ROUTER, DEPLOYER);
        vm.stopPrank();
    }

    function test_launchpad_deploys() public view {
        assertEq(pad.obsd(), OBSD);
        assertEq(pad.treasury(), DEPLOYER);
        assertEq(pad.totalLaunches(), 0);
    }

    function test_launch_creator_token() public {
        address creator = makeAddr("creator");
        uint256 supply = 1_000_000_000e18;
        uint256 obsdSeed = 10_000e18;

        vm.startPrank(DEPLOYER);
        IERC20(OBSD).approve(address(pad), obsdSeed);

        (address token, address pool) = pad.launch(
            "Test Creator Token", "TCREAT", supply, obsdSeed, 80, creator
        );
        vm.stopPrank();

        // Token deployed
        assertTrue(token != address(0));
        assertTrue(pool != address(0));
        assertEq(pad.totalLaunches(), 1);

        // Creator gets 0 tokens — remaining supply was burned
        uint256 creatorBalance = IERC20(token).balanceOf(creator);
        assertEq(creatorBalance, 0);

        // 80% went to pool, 20% was burned → totalSupply = 80% of original
        uint256 poolTokens = supply * 80 / 100;
        uint256 burnedTokens = supply - poolTokens;
        assertEq(CreatorTokenV2(token).totalSupply(), supply - burnedTokens);

        // LaunchPad should hold 0 tokens (all seeded or burned)
        assertEq(IERC20(token).balanceOf(address(pad)), 0);

        // Verify it's a CreatorTokenV2 with correct config
        CreatorTokenV2 ct = CreatorTokenV2(token);
        assertEq(ct.creator(), creator);
        assertEq(ct.treasury(), DEPLOYER);
        assertEq(ct.obsd(), OBSD);
    }

    function test_creator_token_has_transfer_fee() public {
        address creator = makeAddr("creator");
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        uint256 supply = 1_000_000_000e18;
        uint256 obsdSeed = 10_000e18;

        vm.startPrank(DEPLOYER);
        IERC20(OBSD).approve(address(pad), obsdSeed);
        (address token,) = pad.launch("Fee Test", "FEET", supply, obsdSeed, 80, creator);
        vm.stopPrank();

        // Give alice some tokens via deal and update circulating counter
        uint256 transferAmt = 1_000_000e18;
        deal(token, alice, transferAmt);
        // deal() bypasses _update so circulating is stale — fix it
        // circulating slot: use stdstore to update
        uint256 circulatingSlot = 11; // storage slot from forge inspect
        bytes32 currentCirc = vm.load(token, bytes32(uint256(circulatingSlot)));
        vm.store(token, bytes32(uint256(circulatingSlot)), bytes32(uint256(currentCirc) + transferAmt));

        uint256 supplyBefore = IERC20(token).totalSupply();

        // Alice transfers to bob — v2 fee: 1% burn + 1% creator + 1% treasury = 3% total
        vm.prank(alice);
        IERC20(token).transfer(bob, transferAmt);

        uint256 expected = transferAmt - (transferAmt * 300 / 10000); // 97% to recipient
        assertEq(IERC20(token).balanceOf(bob), expected);

        // 1% was burned — totalSupply decreased
        uint256 burnAmount = transferAmt * 100 / 10000; // 1%
        assertEq(IERC20(token).totalSupply(), supplyBefore - burnAmount);

        // 2% (creator + treasury shares) accumulated in token contract for OBSD swap
        uint256 contractBal = IERC20(token).balanceOf(token);
        uint256 expectedFeeInContract = transferAmt * 200 / 10000; // 2%
        assertEq(contractBal, expectedFeeInContract);
    }

    function test_symbol_uniqueness() public {
        uint256 obsdSeed = 10_000e18;
        address creator = makeAddr("creator");

        vm.startPrank(DEPLOYER);
        IERC20(OBSD).approve(address(pad), obsdSeed * 2);

        pad.launch("First", "UNIQUE", 1e27, obsdSeed, 80, creator);

        vm.expectRevert("Symbol taken");
        pad.launch("Second", "UNIQUE", 1e27, obsdSeed, 80, creator);

        vm.stopPrank();
    }

    function test_platform_router_deploys() public view {
        assertEq(router.obsdToken(), OBSD);
        assertEq(router.weth(), WETH);
        assertEq(router.treasury(), DEPLOYER);
        assertEq(router.PLATFORM_FEE_BPS(), 50);
    }

    function test_only_owner_can_launch() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert("Only owner");
        pad.launch("Bad", "BAD", 1e18, 1e18, 50, rando);
    }

    function test_no_creator_token_allocation() public {
        address creator = makeAddr("creator");
        uint256 supply = 1_000_000_000e18;
        uint256 obsdSeed = 10_000e18;

        vm.startPrank(DEPLOYER);
        IERC20(OBSD).approve(address(pad), obsdSeed);
        (address token,) = pad.launch("No Alloc", "NOALLOC", supply, obsdSeed, 80, creator);
        vm.stopPrank();

        // Creator gets 0 tokens
        assertEq(IERC20(token).balanceOf(creator), 0);

        // But creator is correctly set in CreatorToken
        assertEq(CreatorTokenV2(token).creator(), creator);
    }

    function test_burn_does_not_trigger_fee() public {
        address creator = makeAddr("creator");
        uint256 supply = 1_000_000_000e18;
        uint256 obsdSeed = 10_000e18;

        vm.startPrank(DEPLOYER);
        IERC20(OBSD).approve(address(pad), obsdSeed);
        (address token,) = pad.launch("Burn Test", "BRNT", supply, obsdSeed, 80, creator);
        vm.stopPrank();

        CreatorTokenV2 ct = CreatorTokenV2(token);

        // pendingFees should be 0 — burn (to=address(0)) is fee-exempt
        // and LaunchPad is feeExempt so pool seeding also doesn't trigger fees
        assertEq(ct.pendingFees(), 0);

        // No fees accumulated in token contract
        assertEq(IERC20(token).balanceOf(token), 0);
    }

    function test_pool_is_set_on_token() public {
        address creator = makeAddr("creator");
        uint256 supply = 1_000_000_000e18;
        uint256 obsdSeed = 10_000e18;

        vm.startPrank(DEPLOYER);
        IERC20(OBSD).approve(address(pad), obsdSeed);
        (address token, address pool) = pad.launch("Pool Set", "PSET", supply, obsdSeed, 80, creator);
        vm.stopPrank();

        // Pool address is set on the token (needed for buy/sell detection)
        CreatorTokenV2 ct = CreatorTokenV2(token);
        assertEq(ct.pool(), pool);
        assertTrue(pool != address(0));
    }

    function test_creator_launches_tracking() public {
        address creator1 = makeAddr("creator1");
        address creator2 = makeAddr("creator2");
        uint256 obsdSeed = 10_000e18;

        vm.startPrank(DEPLOYER);
        IERC20(OBSD).approve(address(pad), obsdSeed * 3);

        pad.launch("A", "AAAA", 1e27, obsdSeed, 80, creator1);
        pad.launch("B", "BBBB", 1e27, obsdSeed, 80, creator1);
        pad.launch("C", "CCCC", 1e27, obsdSeed, 80, creator2);
        vm.stopPrank();

        assertEq(pad.getCreatorLaunches(creator1).length, 2);
        assertEq(pad.getCreatorLaunches(creator2).length, 1);
    }
}
