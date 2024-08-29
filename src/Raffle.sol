// Layout of the contract
// spdx and pragma
// import
// error
// interface, library, contract
// type defination. eg. struct, enum
// state variable
// event
// modifier
// function

// layout of the function
// constructor
// receive
// fallback
// external
// public
// internal
// private
// view and pure

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.23;

// library
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
// interface
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
// contracts
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * @title Raffle
 * @author Imran Pollob
 * @notice This contract is used to create a raffle
 * @dev This contract uses Chainling VRF 2 to generate random number
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    // error
    error Raffle_NotEnoughEthSent(); // emitter enterRaffle()
    error Raffle_RaffleNotOpen(); // emitter enterRaffle()
    error Raffle_UpkeepNotNeeded(uint256 currenctBalance, uint256 numPlayers, uint256 raffleState); // emitter performUpkeep()
    error Raffle_TransferFailed(); // emitter fulfillRandomWords()

    // interface, library, contract

    // type defination. eg. struct, enum
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // constants
    uint16 private constant REQUEST_CONFFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    // state variable
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_interval; // duration of the raffle
    uint256 private immutable i_entryFee;
    uint32 private immutable i_callbackGasLimit;

    address private s_recentWinner;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    RaffleState private s_raffleState;

    // s_vrfCoordinator should be used by consumers to make requests to vrfCoordinator
    // VRFCoordinatorV2Plus => s_vrfCoordinator;

    // event
    event EnteredRaffle(address indexed player);
    event RequestRaffleWinner(uint256 indexed requestID);
    event WinnerPicked(address indexed winner);

    // modifier

    // function
    // constructor
    // inherited constructors: VRFConsumerBaseV2Plus => constructor(address _vrfCoordinator)
    constructor(
        uint256 subscriptionId,
        bytes32 keyHash,
        uint256 interval,
        uint256 entryFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_subscriptionId = subscriptionId;
        i_keyHash = keyHash;
        i_interval = interval;
        i_entryFee = entryFee;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    // VRFConsumerBaseV2Plus Contract
    //
    // function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual; => handles the VRF response
    // AutomationCompatibleInterface interface
    // function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData); => simulated by the keepers to see if any work actually needs to be performed
    // function performUpkeep(bytes calldata performData) external; => executed by the keepers, via the registry after getting result from checkUpkeep()
    // VRFV2PlusClient library
    // struct RandomWordsRequest {
    //     bytes32 keyHash;
    //     uint256 subId;
    //     uint16 requestConfirmations;
    //     uint32 callbackGasLimit;
    //     uint32 numWords;
    //     bytes extraArgs;
    // }

    // receive

    // fallback

    // external

    // public
    function enterRaffle() public payable {
        // 1. Check the entry fee is enough
        // Following 3 checks are the same
        // require(msg.value >= i_entryFee, "Not enough ETH sent");
        // if (msg.value < i_entryFee) revert("Not enough ETH sent");
        if (msg.value < i_entryFee) revert Raffle_NotEnoughEthSent();

        // 2. check the raffle state is open
        if (s_raffleState != RaffleState.OPEN) revert Raffle_RaffleNotOpen();

        // 3. enter player to the raffle
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // executed by keeper, upkeepNeeded boolean to indicate whether the keeper should call performUpkeep or not
    // tips: while overriding, visibility modifier can be extended meaning external can become public. view/pure can be added
    // unnecessary variables can be commented out
    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = isOpen && timePassed && hasPlayers && hasBalance;
        performData = "0x0";
    }

    // once checkUpkeep is returning true, this function is called and it kicks of a Chainlink VRF call to get a random number
    function performUpkeep(bytes calldata /*performData*/ ) external override {
        // 1. check if upkeep is needed or not
        (bool upkeepNeeded,) = checkUpkeep(""); // need to change storage location of checkdata in checkUpkeep function
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        // 2. chnage the raffle state
        s_raffleState = RaffleState.CALCULATING;

        // 3. request random words
        // will revert if subscription is not set and funded
        // v2   https://docs.chain.link/vrf/v2/subscription/examples/get-a-random-number
        // v2.5 https://docs.chain.link/vrf/v2-5/overview/subscription#set-up-your-contract-and-request
        uint256 requestID = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFFIRMATION,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            })
        );

        emit RequestRaffleWinner(requestID);
    }

    // VRF node will call this function with defined no of randomWords, currently defined as 1
    function fulfillRandomWords(uint256, /*requestId*/ uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;

        emit WinnerPicked(recentWinner);

        (bool success,) = recentWinner.call{value: address(this).balance}("");

        if (!success) revert Raffle_TransferFailed();
    }

    // internal

    // private

    // view and pure
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntryFee() public view returns (uint256) {
        return i_entryFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
