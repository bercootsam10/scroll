// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { DSTestPlus } from "solmate/test/utils/DSTestPlus.sol";

import { L1MessageQueue } from "../L1/rollup/L1MessageQueue.sol";
import { IScrollChain, ScrollChain } from "../L1/rollup/ScrollChain.sol";
import { Whitelist } from "../L2/predeploys/Whitelist.sol";
import { IL1ScrollMessenger, L1ScrollMessenger } from "../L1/L1ScrollMessenger.sol";
import { L2ScrollMessenger } from "../L2/L2ScrollMessenger.sol";

contract L1ScrollMessengerTest is DSTestPlus {
  L2ScrollMessenger internal l2Messenger;

  address internal feeVault;

  L1ScrollMessenger internal l1Messenger;
  ScrollChain internal scrollChain;
  L1MessageQueue internal l1MessageQueue;

  function setUp() public {
    // Deploy L2 contracts
    l2Messenger = new L2ScrollMessenger(address(0), address(0), address(0));

    // Deploy L1 contracts
    scrollChain = new ScrollChain(0, 0, bytes32(0));
    l1MessageQueue = new L1MessageQueue();
    l1Messenger = new L1ScrollMessenger();

    // Initialize L1 contracts
    l1Messenger.initialize(address(l2Messenger), feeVault, address(scrollChain), address(l1MessageQueue));
    l1MessageQueue.initialize(address(l1Messenger), address(0));
    scrollChain.initialize(address(l1MessageQueue));
  }

  function testForbidCallFromL2() external {
    IScrollChain.Batch memory genesisBatch;
    genesisBatch.newStateRoot = bytes32(uint256(1));
    genesisBatch.blocks = new IScrollChain.BlockContext[](1);
    genesisBatch.blocks[0].blockHash = bytes32(uint256(1));
    scrollChain.importGenesisBatch(genesisBatch);

    IL1ScrollMessenger.L2MessageProof memory proof;
    proof.batchHash = scrollChain.lastFinalizedBatchHash();

    hevm.expectRevert("Forbid to call message queue");
    l1Messenger.relayMessageWithProof(address(this), address(l1MessageQueue), 0, 0, new bytes(0), proof);

    hevm.expectRevert("Forbid to call self");
    l1Messenger.relayMessageWithProof(address(this), address(l1Messenger), 0, 0, new bytes(0), proof);
  }

  function testSendMessage(uint256 exceedValue, address refundAddress) external {
    hevm.assume(refundAddress.code.length == 0);
    hevm.assume(uint256(uint160(refundAddress)) > 100); // ignore some precompile contracts
    hevm.assume(refundAddress != address(this));

    exceedValue = bound(exceedValue, 1, address(this).balance / 2);

    // Insufficient msg.value
    hevm.expectRevert("Insufficient msg.value");
    l1Messenger.sendMessage(address(0), 1, new bytes(0), 0, refundAddress);

    // refund exceed fee
    uint256 balanceBefore = refundAddress.balance;
    l1Messenger.sendMessage{ value: 1 + exceedValue }(address(0), 1, new bytes(0), 0, refundAddress);
    assertEq(balanceBefore + exceedValue, refundAddress.balance);
  }
}