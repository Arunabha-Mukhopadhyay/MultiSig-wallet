// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSig.sol";

contract MockReceiver {
    uint256 public received;

    receive() external payable {
        received += msg.value;
    }

    function setReceived(uint256 value) external {
        received = value;
    }
}

contract MultiSigTest is Test {
    MultiSig public multiSig;
    MockReceiver public receiver;

    address public owner1 = makeAddr("owner1");
    address public owner2 = makeAddr("owner2");
    address public owner3 = makeAddr("owner3");
    address public stranger = makeAddr("stranger");

    bytes32 public constant DESCRIPTION_HASH = keccak256("test transaction");

    function setUp() public {
        receiver = new MockReceiver();
        multiSig = _deployMultiSig(_defaultOwners(), 2);
        vm.deal(address(multiSig), 10 ether);
    }

    function _defaultOwners() internal view returns (address[] memory owners) {
        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
    }

    function _deployMultiSig(address[] memory owners, uint256 requiredConfirmations)
        internal
        returns (MultiSig)
    {
        return new MultiSig(owners, requiredConfirmations);
    }

    function test_constructor_setsRequiredConfirmations() public view {
        assertEq(multiSig.requiredConfirmations(), 2);
    }

    function test_constructor_revertsWhenRequiredConfirmationsIsZero() public {
        vm.expectRevert("Invalid required confirmations");
        _deployMultiSig(_defaultOwners(), 0);
    }

    function test_constructor_revertsWhenRequiredConfirmationsExceedsOwnerCount() public {
        vm.expectRevert("Invalid required confirmations");
        _deployMultiSig(_defaultOwners(), 4);
    }

    function test_receive_acceptsEth() public {
        vm.deal(address(this), 1 ether);
        (bool sent,) = address(multiSig).call{value: 1 ether}("");

        assertTrue(sent);
        assertEq(address(multiSig).balance, 11 ether);
    }

    function test_submitTransaction_createsPendingTransaction() public {
        vm.startPrank(owner1);
        vm.expectEmit(true, true, true, true);
        emit MultiSig.SubmitTransaction(0, owner1, address(receiver), 1 ether, "", DESCRIPTION_HASH);
        uint256 transactionId = multiSig.submitTransaction(address(receiver), 1 ether, "", DESCRIPTION_HASH);
        vm.stopPrank();

        assertEq(transactionId, 0);
        assertEq(multiSig.getTransactionCount(), 1);

        (bool executed, address to, uint256 value, bytes memory data, bytes32 descriptionHash, uint256 confirmations) =
            multiSig.getTransaction(0);

        assertFalse(executed);
        assertEq(to, address(receiver));
        assertEq(value, 1 ether);
        assertEq(data.length, 0);
        assertEq(descriptionHash, DESCRIPTION_HASH);
        assertEq(confirmations, 1);
    }

    function test_submitTransaction_autoConfirmsSubmitter() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(receiver), 1 ether, "", DESCRIPTION_HASH);

        assertTrue(multiSig.isConfirmed(0, owner1));
        assertEq(multiSig.getConfirmations(0), 1);
    }

    function test_submitTransaction_revertsForNonOwner() public {
        vm.prank(stranger);
        vm.expectRevert("Admin restricted access");
        multiSig.submitTransaction(address(receiver), 1 ether, "", DESCRIPTION_HASH);
    }

    function test_submitTransaction_revertsForInvalidDestination() public {
        vm.prank(owner1);
        vm.expectRevert("Invalid destination");
        multiSig.submitTransaction(address(0), 1 ether, "", DESCRIPTION_HASH);
    }

    function test_confirmTransaction_incrementsConfirmations() public {
        MultiSig wallet = _deployMultiSig(_defaultOwners(), 3);

        vm.prank(owner1);
        wallet.submitTransaction(address(receiver), 0, "", DESCRIPTION_HASH);

        vm.prank(owner2);
        vm.expectEmit(true, true, false, true);
        emit MultiSig.ConfirmTransaction(0, owner2);
        wallet.confirmTransaction(0);

        assertTrue(wallet.isConfirmed(0, owner2));
        assertEq(wallet.getConfirmations(0), 2);
    }

    function test_confirmTransaction_revertsForDoubleConfirm() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(receiver), 0, "", DESCRIPTION_HASH);

        vm.prank(owner1);
        vm.expectRevert("Transaction already confirmed");
        multiSig.confirmTransaction(0);
    }

    function test_confirmTransaction_autoExecutesAtThreshold() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(receiver), 1 ether, "", DESCRIPTION_HASH);

        vm.prank(owner2);
        multiSig.confirmTransaction(0);

        (bool executed,,,,,) = multiSig.getTransaction(0);
        assertTrue(executed);
        assertEq(address(receiver).balance, 1 ether);
    }

    function test_revokeConfirmation_decrementsConfirmations() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(receiver), 0, "", DESCRIPTION_HASH);

        vm.prank(owner1);
        vm.expectEmit(true, true, false, true);
        emit MultiSig.RevokeConfirmation(0, owner1);
        multiSig.revokeConfirmation(0);

        assertFalse(multiSig.isConfirmed(0, owner1));
        assertEq(multiSig.getConfirmations(0), 0);
    }

    function test_revokeConfirmation_revertsWhenNotConfirmed() public {
        MultiSig wallet = _deployMultiSig(_defaultOwners(), 3);

        vm.prank(owner1);
        wallet.submitTransaction(address(receiver), 0, "", DESCRIPTION_HASH);

        vm.prank(owner2);
        vm.expectRevert("Transaction not confirmed");
        wallet.revokeConfirmation(0);
    }

    function test_executeTransaction_sendsEthWithEnoughConfirmations() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(receiver), 2 ether, "", DESCRIPTION_HASH);

        vm.prank(owner2);
        vm.expectEmit(true, true, false, true);
        emit MultiSig.ExecuteTransaction(0, owner2);
        multiSig.confirmTransaction(0);

        (bool executed,,,,,) = multiSig.getTransaction(0);
        assertTrue(executed);
        assertEq(address(receiver).balance, 2 ether);
    }

    function test_executeTransaction_executesContractCall() public {
        bytes memory data = abi.encodeWithSelector(MockReceiver.setReceived.selector, 42);

        vm.prank(owner1);
        multiSig.submitTransaction(address(receiver), 0, data, DESCRIPTION_HASH);

        vm.prank(owner2);
        multiSig.confirmTransaction(0);

        assertEq(receiver.received(), 42);
    }

    function test_executeTransaction_revertsWhenNotEnoughConfirmations() public {
        MultiSig wallet = _deployMultiSig(_defaultOwners(), 3);

        vm.prank(owner1);
        wallet.submitTransaction(address(receiver), 1 ether, "", DESCRIPTION_HASH);

        vm.prank(owner2);
        vm.expectRevert("Not enough confirmations");
        wallet.executeTransaction(0);
    }

    function test_executeTransaction_revertsWhenAlreadyExecuted() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(receiver), 1 ether, "", DESCRIPTION_HASH);

        vm.prank(owner2);
        multiSig.confirmTransaction(0);

        vm.prank(owner3);
        vm.expectRevert("Transaction already executed");
        multiSig.executeTransaction(0);
    }

    function test_getTransactionCount_returnsSubmittedTransactions() public view {
        assertEq(multiSig.getTransactionCount(), 0);
    }

    function test_getTransaction_returnsStoredTransaction() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(receiver), 1 ether, "", DESCRIPTION_HASH);

        (bool executed, address to, uint256 value, bytes memory data, bytes32 descriptionHash, uint256 confirmations) =
            multiSig.getTransaction(0);

        assertFalse(executed);
        assertEq(to, address(receiver));
        assertEq(value, 1 ether);
        assertEq(data.length, 0);
        assertEq(descriptionHash, DESCRIPTION_HASH);
        assertEq(confirmations, 1);
    }

    function test_getTransaction_revertsForInvalidId() public {
        vm.expectRevert("Transaction does not exist");
        multiSig.getTransaction(0);
    }

    function test_getConfirmations_returnsConfirmationCount() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(receiver), 0, "", DESCRIPTION_HASH);

        assertEq(multiSig.getConfirmations(0), 1);
    }

    function test_getConfirmations_revertsForInvalidId() public {
        vm.expectRevert("Transaction does not exist");
        multiSig.getConfirmations(0);
    }
}
