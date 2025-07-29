// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/CrossChainSwap.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract CrossChainSwapTest is Test {
    CrossChainSwap swap;
    MockERC20 token;
    address fusion = address(0x123); // Mock 1inch Fusion+ address
    address user = address(0x456);
    address recipient = address(0x789);

    function setUp() public {
        swap = new CrossChainSwap(fusion);
        token = new MockERC20("TestToken", "TST", 1000 ether);
        vm.deal(user, 10 ether);
        vm.startPrank(user);
        token.approve(address(swap), 1000 ether);
        vm.stopPrank();
    }

    function testInitiateAndCompleteSwap() public {
        uint256 amount = 10 ether;
        bytes32 secret = bytes32(uint256(12345));
        bytes32 secretHash = keccak256(abi.encodePacked(secret));
        uint256 timelock = block.timestamp + 1 hours;

        vm.startPrank(user);
        swap.initiateSwap(address(token), amount, secretHash, timelock);
        bytes32 swapId = keccak256(abi.encodePacked(user, address(token), amount, secretHash, timelock));
        vm.stopPrank();

        vm.startPrank(recipient);
        swap.completeSwap(swapId, secret);
        assertEq(token.balanceOf(recipient), amount);
        // assertFalse(swap.swaps(swapId).active);
        vm.stopPrank();
    }

    function testRefundSwap() public {
        uint256 amount = 10 ether;
        bytes32 secretHash = keccak256(abi.encodePacked(bytes32(uint256(12345))));
        uint256 timelock = block.timestamp + 1 hours;

        vm.startPrank(user);
        swap.initiateSwap(address(token), amount, secretHash, timelock);
        bytes32 swapId = keccak256(abi.encodePacked(user, address(token), amount, secretHash, timelock));
        vm.warp(timelock + 1); // Fast-forward time
        swap.refundSwap(swapId);
        assertEq(token.balanceOf(user), 1000 ether); // Initial balance restored
        // assertFalse(swap.swaps(swapId).active);
        vm.stopPrank();
    }

    function testPartialCompleteSwap() public {
        uint256 amount = 10 ether;
        uint256 partialAmount = 3 ether;
        bytes32 secret = bytes32(uint256(12345));
        bytes32 secretHash = keccak256(abi.encodePacked(secret));
        uint256 timelock = block.timestamp + 1 hours;

        vm.startPrank(user);
        swap.initiateSwap(address(token), amount, secretHash, timelock);
        bytes32 swapId = keccak256(abi.encodePacked(user, address(token), amount, secretHash, timelock));
        vm.stopPrank();

        vm.startPrank(recipient);
        swap.partialCompleteSwap(swapId, secret, partialAmount);
        assertEq(token.balanceOf(recipient), partialAmount);
        // assertEq(swap.swaps(swapId).amount, amount - partialAmount);
        vm.stopPrank();
    }
}
