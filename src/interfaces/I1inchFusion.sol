// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface I1inchFusion {
    function getQuote(address srcToken, address dstToken, uint256 amount) external view returns (uint256);
}