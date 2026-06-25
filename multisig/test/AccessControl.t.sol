// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {AccessControl} from "../src/AccessControl.sol";

contract AccessControlTest is Test {
    AccessControl public accessControl;

    address public owner1 = makeAddr("owner1");
    address public owner2 = makeAddr("owner2");
    address public owner3 = makeAddr("owner3");
    address public owner4 = makeAddr("owner4");
    address public stranger = makeAddr("stranger");

    function setUp() public {
        accessControl = _deployAccessControl(_defaultOwners());
    }

    function _defaultOwners() internal view returns (address[] memory owners) {
        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
    }

    function _deployAccessControl(address[] memory owners) internal returns (AccessControl) {
        return new AccessControl(owners);
    }

    function test_constructor_setsAdminAndOwners() public view {
        assertEq(accessControl.getAdmin(), address(this));
        assertEq(accessControl.getOwnerCount(), 3);
        assertTrue(accessControl.isOwner(owner1));
        assertTrue(accessControl.isOwner(owner2));
        assertTrue(accessControl.isOwner(owner3));
    }

    function test_constructor_revertsWhenFewerThanThreeOwners() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vm.expectRevert("At least 3 owners are required");
        _deployAccessControl(owners);
    }

    function test_constructor_revertsForNullOwner() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = address(0);
        owners[2] = owner3;

        vm.expectRevert("Address is null");
        _deployAccessControl(owners);
    }

    function test_constructor_revertsForDuplicateOwner() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner1;
        owners[2] = owner3;

        vm.expectRevert("Duplicate owner");
        _deployAccessControl(owners);
    }

    function test_getAdmin_returnsDeployer() public view {
        assertEq(accessControl.getAdmin(), address(this));
    }

    function test_getOwners_returnsInitialOwners() public view {
        address[] memory owners = accessControl.getOwners();

        assertEq(owners.length, 3);
        assertEq(owners[0], owner1);
        assertEq(owners[1], owner2);
        assertEq(owners[2], owner3);
    }

    function test_getOwnerCount_returnsInitialCount() public view {
        assertEq(accessControl.getOwnerCount(), 3);
    }

    function test_addNewOwner_addsOwnerWhenCalledByAdmin() public {
        accessControl.addNewOwner(owner4);

        assertTrue(accessControl.isOwner(owner4));
        assertEq(accessControl.getOwnerCount(), 4);
    }

    function test_addNewOwner_addsOwnerWhenCalledByOwner() public {
        vm.prank(owner1);
        accessControl.addNewOwner(owner4);

        assertTrue(accessControl.isOwner(owner4));
        assertEq(accessControl.getOwnerCount(), 4);
    }

    function test_addNewOwner_revertsForNonOwner() public {
        vm.prank(stranger);
        vm.expectRevert("Admin restricted access");
        accessControl.addNewOwner(owner4);
    }

    function test_addNewOwner_revertsForNullAddress() public {
        vm.expectRevert("Address is null");
        accessControl.addNewOwner(address(0));
    }

    function test_addNewOwner_revertsForExistingOwner() public {
        vm.expectRevert("Address is already an owner");
        accessControl.addNewOwner(owner1);
    }

    function test_addNewOwner_revertsWhenMaxOwnersReached() public {
        for (uint256 i = 0; i < 7; i++) {
            accessControl.addNewOwner(makeAddr(string.concat("extraOwner", vm.toString(i))));
        }

        assertEq(accessControl.getOwnerCount(), 10);

        vm.expectRevert("Max 10 owners allowed");
        accessControl.addNewOwner(makeAddr("eleventhOwner"));
    }

    function test_removeOwner_removesOwnerWhenMoreThanThreeExist() public {
        accessControl.addNewOwner(owner4);

        accessControl.removeOwner(owner4);

        assertFalse(accessControl.isOwner(owner4));
        assertEq(accessControl.getOwnerCount(), 3);
    }

    function test_removeOwner_revertsForNonOwner() public {
        accessControl.addNewOwner(owner4);

        vm.prank(stranger);
        vm.expectRevert("Admin restricted access");
        accessControl.removeOwner(owner4);
    }

    function test_removeOwner_revertsForNullAddress() public {
        vm.expectRevert("Address is null");
        accessControl.removeOwner(address(0));
    }

    function test_removeOwner_revertsWhenTargetIsNotOwner() public {
        vm.expectRevert("Not an owner");
        accessControl.removeOwner(stranger);
    }

    function test_removeOwner_revertsWhenOnlyThreeOwnersRemain() public {
        vm.expectRevert("At least 3 owners are required");
        accessControl.removeOwner(owner1);
    }

    function test_changeAdmin_updatesAdmin() public {
        accessControl.changeAdmin(owner4);

        assertEq(accessControl.getAdmin(), owner4);
    }

    function test_changeAdmin_addsNewAdminToOwnersIfNeeded() public {
        accessControl.changeAdmin(stranger);

        assertTrue(accessControl.isOwner(stranger));
        assertEq(accessControl.getOwnerCount(), 4);
    }

    function test_changeAdmin_revertsWhenCalledByNonAdmin() public {
        vm.prank(owner1);
        vm.expectRevert("Only admin can change admin");
        accessControl.changeAdmin(owner4);
    }

    function test_changeAdmin_revertsForNullAddress() public {
        vm.expectRevert("Address is null");
        accessControl.changeAdmin(address(0));
    }
}
