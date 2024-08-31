// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        vm.startBroadcast(networkConfig.account);

        Raffle raffle = new Raffle(
            helperConfig.subscriptionId,
            helperConfig.keyHash,
            helperConfig.interval,
            helperConfig.entryFee,
            helperConfig.callbackGasLimit,
            helperConfig.vrfCoordinatorV2_5
        );

        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
