// SPDX-License-License: MIT
pragma solidity ^0.8.0;

import "./interfaces/I1inchFusion.sol";
import "./interfaces/IERC20.sol";

contract CrossChainSwap {
    address public owner;
    I1inchFusion public fusion;
    mapping(bytes32 => Swap) public swaps;

    struct Swap {
        address initiator;
        address token;
        uint256 amount;
        bytes32 secretHash;
        uint256 timelock;
        bool active;
    }

    event SwapInitiated(
        bytes32 indexed swapId, address initiator, address token, uint256 amount, bytes32 secretHash, uint256 timelock
    );
    event SwapCompleted(bytes32 indexed swapId, address receiver, uint256 amount);
    event SwapRefunded(bytes32 indexed swapId);

    constructor(address _fusion) {
        owner = msg.sender;
        fusion = I1inchFusion(_fusion);
    }

    // Initiate a swap by locking tokens
    function initiateSwap(address _token, uint256 _amount, bytes32 _secretHash, uint256 _timelock) external payable {
        require(_timelock > block.timestamp, "Timelock must be in future");
        require(_amount > 0, "Amount must be greater than 0");

        // Transfer ERC-20 tokens to contract
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        bytes32 swapId = keccak256(abi.encodePacked(msg.sender, _token, _amount, _secretHash, _timelock));
        swaps[swapId] = Swap({
            initiator: msg.sender,
            token: _token,
            amount: _amount,
            secretHash: _secretHash,
            timelock: _timelock,
            active: true
        });

        emit SwapInitiated(swapId, msg.sender, _token, _amount, _secretHash, _timelock);
    }

    // Complete a swap by revealing the secret
    function completeSwap(bytes32 _swapId, bytes32 _secret) external {
        Swap storage swap = swaps[_swapId];
        require(swap.active, "Swap not active");
        require(keccak256(abi.encodePacked(_secret)) == swap.secretHash, "Invalid secret");
        require(block.timestamp < swap.timelock, "Timelock expired");

        swap.active = false;
        IERC20(swap.token).transfer(msg.sender, swap.amount);
        emit SwapCompleted(_swapId, msg.sender, swap.amount);
    }

    // Refund if timelock expires
    function refundSwap(bytes32 _swapId) external {
        Swap storage swap = swaps[_swapId];
        require(swap.active, "Swap not active");
        require(block.timestamp >= swap.timelock, "Timelock not expired");
        require(msg.sender == swap.initiator, "Only initiator can refund");

        swap.active = false;
        IERC20(swap.token).transfer(swap.initiator, swap.amount);
        emit SwapRefunded(_swapId);
    }

    // Stretch goal: Partial fills
    function partialCompleteSwap(bytes32 _swapId, bytes32 _secret, uint256 _partialAmount) external {
        Swap storage swap = swaps[_swapId];
        require(swap.active, "Swap not active");
        require(keccak256(abi.encodePacked(_secret)) == swap.secretHash, "Invalid secret");
        require(block.timestamp < swap.timelock, "Timelock expired");
        require(_partialAmount <= swap.amount, "Partial amount exceeds total");

        swap.amount -= _partialAmount;
        if (swap.amount == 0) swap.active = false;
        IERC20(swap.token).transfer(msg.sender, _partialAmount);
        emit SwapCompleted(_swapId, msg.sender, _partialAmount);
    }

    // Query 1inch Fusion+ for quote
    function getQuote(address _srcToken, address _dstToken, uint256 _amount) external view returns (uint256) {
        return fusion.getQuote(_srcToken, _dstToken, _amount);
    }
}
