// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {CreateSubscription, AddConsumer, FundSubscription} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        if (networkConfig.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.subscriptionId, networkConfig.vrfCoordinatorV2_5) =
                createSubscription.createSubscription(networkConfig.vrfCoordinatorV2_5, networkConfig.account);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                networkConfig.vrfCoordinatorV2_5,
                networkConfig.subscriptionId,
                networkConfig.link,
                networkConfig.account
            );

            helperConfig.setConfig(block.chainid, networkConfig);
        }

        vm.startBroadcast(networkConfig.account);
        Raffle raffle = new Raffle(
            networkConfig.subscriptionId,
            networkConfig.keyHash,
            networkConfig.interval,
            networkConfig.entryFee,
            networkConfig.callbackGasLimit,
            networkConfig.vrfCoordinatorV2_5
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle), networkConfig.vrfCoordinatorV2_5, networkConfig.subscriptionId, networkConfig.account
        );

        return (raffle, helperConfig);
    }
}
