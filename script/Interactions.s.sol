// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorV2_5 = helperConfig.getConfigByChainId(block.chainid).vrfCoordinatorV2_5;
        address account = helperConfig.getConfigByChainId(block.chainid).account;

        return createSubscription(vrfCoordinatorV2_5, account);
    }

    function createSubscription(address vrfCoordinatorV2_5, address account) public returns (uint256, address) {
        console.log("Creating subscription of chainid: ", block.chainid);

        vm.startBroadcast(account);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription ID is: ", subscriptionId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");

        return (subscriptionId, vrfCoordinatorV2_5);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address contractToAddToVrf,
        address vrfCoordinatorV2_5,
        uint256 subscriptionId,
        address account
    ) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2_5);
        console.log("On ChainID: ", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).addConsumer(subscriptionId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);

        HelperConfig helperConfig = new HelperConfig();

        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinatorV2_5;
        address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2_5, subscriptionId, account);
    }
}

contract FundSubscription is CodeConstants, Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function run() external {
        HelperConfig helperConfig = new HelperConfig();

        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinatorV2_5;
        address link = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();

            (uint256 updateSubscriptionId, address updateVRF) = createSubscription.run();
            subscriptionId = updateSubscriptionId;
            vrfCoordinatorV2_5 = updateVRF;

            console.log("New subscriptionId is created: ", subscriptionId);
            console.log("vrfCoordinatorV2_5 address: ", vrfCoordinatorV2_5);
        }
    }

    function fundSubscription(address vrfCoordinatorV2_5, uint256 subscriptionId, address link, address account)
        public
    {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2_5);
        console.log("On ChainID: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));

            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinatorV2_5, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }
}
