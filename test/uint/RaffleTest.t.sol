// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants {
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    Raffle public raffle;
    HelperConfig public helperConfig;
    LinkToken link;

    uint256 subscriptionId;
    bytes32 keyHash;
    uint256 interval;
    uint256 entryFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        subscriptionId = networkConfig.subscriptionId;
        keyHash = networkConfig.keyHash;
        interval = networkConfig.interval;
        entryFee = networkConfig.entryFee;
        callbackGasLimit = networkConfig.callbackGasLimit;
        vrfCoordinatorV2_5 = networkConfig.vrfCoordinatorV2_5;

        link = LinkToken(networkConfig.link);

        vm.startPrank(msg.sender);
        
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);

            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subscriptionId, LINK_BALANCE);
        }

        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);

        vm.stopPrank();
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // function testRaffleRevertsWHenYouDontPayEnought() public {
    //     vm.prank(PLAYER);
    //     vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
    //     raffle.enterRaffle();
    // }

    // function testRaffleRecordsPlayerWhenTheyEnter() public {
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entryFee}();
    //     address playerRecorded = raffle.getPlayer(0);
    //     assert(playerRecorded == PLAYER);
    // }

    // function testEmitsEventOnEntrance() public {
    //     vm.prank(PLAYER);
    //     vm.expectEmit(true, false, false, false, address(raffle));
    //     emit RaffleEnter(PLAYER);
    //     raffle.enterRaffle{value: entryFee}();
    // }

    
}
