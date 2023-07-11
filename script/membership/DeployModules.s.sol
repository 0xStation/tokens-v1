// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {EthPurchaseModuleV2} from "src/membership/modules/EthPurchaseModuleV2.sol";
import {StablecoinPurchaseModuleV2} from "src/membership/modules/StablecoinPurchaseModuleV2.sol";
import {FreeMintModuleV2} from "src/membership/modules/FreeMintModuleV2.sol";

// forge script script/modules/DeployFixedETHPurchaseModule.s.sol:Deploy --fork-url $GOERLI_RPC_URL --keystores $ETH_KEYSTORE --password $KEYSTORE_PASSWORD --sender $ETH_FROM --broadcast
// forge verify-contract 0x928d70acd89cc4d18f7ac9d28cf77646ea42bd4a ./src/modules/FixedETHPurchaseModule.sol:FixedETHPurchaseModule $ETHERSCAN_API_KEY --chain-id 5
contract Deploy is Script {
    address owner = 0x016562aA41A8697720ce0943F003141f5dEAe006; // sym

    uint256 fee = 0.0001 ether; // ethereum
    // uint256 fee = 2 ether; // polygon

    address USDC = 0x016562aA41A8697720ce0943F003141f5dEAe006; // goerli
    address DAI = 0x016562aA41A8697720ce0943F003141f5dEAe006; // goerli

    function run() public {
        vm.startBroadcast();

        new FreeMintModuleV2(owner, fee);
        new EthPurchaseModuleV2(owner, fee);

        address[] memory stablecoins = new address[](1);
        stablecoins[0] = USDC;
        stablecoins[0] = DAI;
        new StablecoinPurchaseModuleV2(owner, fee, 2, "USD", stablecoins);

        vm.stopBroadcast();
    }
}
