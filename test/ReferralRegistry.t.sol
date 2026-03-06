// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ReferralRegistry} from "../src/ReferralRegistry.sol";

contract ReferralRegistryTest is Test {
    ReferralRegistry registry;
    address owner = address(this);
    address referrer1 = makeAddr("referrer1");
    address referrer2 = makeAddr("referrer2");
    address token1 = makeAddr("token1");
    address token2 = makeAddr("token2");
    address token3 = makeAddr("token3");

    bytes32 code1 = keccak256("ALPHA");
    bytes32 code2 = keccak256("BETA");

    function setUp() public {
        registry = new ReferralRegistry();
    }

    // ===== registerReferrer =====

    function test_registerReferrer() public {
        vm.prank(referrer1);
        registry.registerReferrer(code1);

        assertEq(registry.codeToReferrer(code1), referrer1);
        assertEq(registry.referrerToCode(referrer1), code1);
    }

    function test_registerReferrer_emitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit ReferralRegistry.ReferrerRegistered(referrer1, code1);

        vm.prank(referrer1);
        registry.registerReferrer(code1);
    }

    function test_registerReferrer_revertEmptyCode() public {
        vm.prank(referrer1);
        vm.expectRevert("Empty code");
        registry.registerReferrer(bytes32(0));
    }

    function test_registerReferrer_revertCodeTaken() public {
        vm.prank(referrer1);
        registry.registerReferrer(code1);

        vm.prank(referrer2);
        vm.expectRevert("Code taken");
        registry.registerReferrer(code1);
    }

    function test_registerReferrer_revertAlreadyRegistered() public {
        vm.prank(referrer1);
        registry.registerReferrer(code1);

        vm.prank(referrer1);
        vm.expectRevert("Already registered");
        registry.registerReferrer(code2);
    }

    // ===== recordReferral =====

    function test_recordReferral() public {
        vm.prank(referrer1);
        registry.registerReferrer(code1);

        registry.recordReferral(token1, referrer1);

        assertEq(registry.getReferrer(token1), referrer1);
        assertEq(registry.getReferralCount(referrer1), 1);

        address[] memory tokens = registry.getReferredTokens(referrer1);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token1);
    }

    function test_recordReferral_multiple() public {
        vm.prank(referrer1);
        registry.registerReferrer(code1);

        registry.recordReferral(token1, referrer1);
        registry.recordReferral(token2, referrer1);
        registry.recordReferral(token3, referrer1);

        assertEq(registry.getReferralCount(referrer1), 3);
    }

    function test_recordReferral_emitsEvent() public {
        vm.prank(referrer1);
        registry.registerReferrer(code1);

        vm.expectEmit(true, true, false, false);
        emit ReferralRegistry.ReferralRecorded(token1, referrer1);

        registry.recordReferral(token1, referrer1);
    }

    function test_recordReferral_revertNotOwner() public {
        vm.prank(referrer1);
        registry.registerReferrer(code1);

        vm.prank(referrer1);
        vm.expectRevert("Not owner");
        registry.recordReferral(token1, referrer1);
    }

    function test_recordReferral_revertZeroToken() public {
        vm.prank(referrer1);
        registry.registerReferrer(code1);

        vm.expectRevert("Zero token");
        registry.recordReferral(address(0), referrer1);
    }

    function test_recordReferral_revertZeroReferrer() public {
        vm.expectRevert("Zero referrer");
        registry.recordReferral(token1, address(0));
    }

    function test_recordReferral_revertAlreadyReferred() public {
        vm.prank(referrer1);
        registry.registerReferrer(code1);

        registry.recordReferral(token1, referrer1);

        vm.expectRevert("Already referred");
        registry.recordReferral(token1, referrer1);
    }

    function test_recordReferral_revertNotAReferrer() public {
        vm.expectRevert("Not a referrer");
        registry.recordReferral(token1, referrer2);
    }

    // ===== getReferrer =====

    function test_getReferrer_returnsZeroIfNone() public view {
        assertEq(registry.getReferrer(token1), address(0));
    }

    // ===== setReferralFeeBps =====

    function test_setReferralFeeBps() public {
        assertEq(registry.referralFeeBps(), 500);

        registry.setReferralFeeBps(1000);
        assertEq(registry.referralFeeBps(), 1000);
    }

    function test_setReferralFeeBps_emitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit ReferralRegistry.ReferralFeeUpdated(500, 1000);

        registry.setReferralFeeBps(1000);
    }

    function test_setReferralFeeBps_revertTooHigh() public {
        vm.expectRevert("Fee too high");
        registry.setReferralFeeBps(2001);
    }

    function test_setReferralFeeBps_revertNotOwner() public {
        vm.prank(referrer1);
        vm.expectRevert("Not owner");
        registry.setReferralFeeBps(1000);
    }

    // ===== transferOwnership =====

    function test_transferOwnership() public {
        registry.transferOwnership(referrer1);
        assertEq(registry.owner(), referrer1);
    }

    function test_transferOwnership_revertZeroAddress() public {
        vm.expectRevert("Zero address");
        registry.transferOwnership(address(0));
    }

    function test_transferOwnership_revertNotOwner() public {
        vm.prank(referrer1);
        vm.expectRevert("Not owner");
        registry.transferOwnership(referrer1);
    }

    // ===== Fuzz =====

    function testFuzz_registerAndRecord(bytes32 code, address referrer, address token) public {
        vm.assume(code != bytes32(0));
        vm.assume(referrer != address(0));
        vm.assume(token != address(0));

        vm.prank(referrer);
        registry.registerReferrer(code);

        registry.recordReferral(token, referrer);

        assertEq(registry.getReferrer(token), referrer);
        assertEq(registry.getReferralCount(referrer), 1);
    }
}
