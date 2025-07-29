// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/CrossChainSwap.sol";

contract DeployCrossChainSwap is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address fusionAddress = 0x1234567890AbcdEF1234567890aBcdef12345678;
        CrossChainSwap swap = new CrossChainSwap(fusionAddress);
        console.log("CrossChainSwap deployed to:", address(swap));

        vm.stopBroadcast();
    }
}
