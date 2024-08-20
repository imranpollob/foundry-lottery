// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.23;

// Layout of the contract
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

/**
 * @title Raffle
 * @author Imran Pollob
 * @notice This contract is used to create a raffle
 * @dev This contract uses Chainling VRF 2 to generate random number
 */
contract Raffle {
    // error
    error Raffle_NotEnoughEthSent();

    // interface, library, contract

    // type defination. eg. struct, enum

    // state variable
    uint256 private immutable i_entryFee;
    // duration of the raffle
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastRaffleTime;

    // event
    event EnteredRaffle(address indexed player);

    // modifier

    // function
    // constructor
    constructor(uint256 _entryFee, uint256 _interval) {
        i_entryFee = _entryFee;
        i_interval = _interval;
        s_lastRaffleTime = block.timestamp;
    }

    // receive

    // fallback

    // external

    // public
    function enterRaffle() public payable {
        // require(msg.value >= i_entryFee, "Not enough ETH sent");
        // if (msg.value < i_entryFee) revert("Not enough ETH sent");
        if (msg.value < i_entryFee) revert Raffle_NotEnoughEthSent();

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public {
        if (block.timestamp - s_lastRaffleTime < i_interval) {
            revert("Raffle is still running");
        }
    }

    // internal

    // private

    // view and pure
    function getEntryFee() public view returns (uint256) {
        return i_entryFee;
    }
}
