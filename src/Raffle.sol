// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";


/**
 * @title Raffle Contract
 * @author Jeremia Geraldi
 * @notice This contract is for creating sample Raffle applications
 * @dev This implements the Chainlink VRF Version 2.5
 */

contract Raffle is VRFConsumerBaseV2Plus{
    // Custom errors
    error Raffle__NotEnoughETHEntered();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__RequirementNotMet(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);


    //Type Decalarations (Since bool is not enough for future use cases)
    enum RaffleState {
        OPEN,       // 0
        CALCULATING // 1
    }

    // State Variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev the inteval duration of the raffle in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_gasLimit;
    address payable[] public s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_RaffleState;

    // Events

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint256 subId, uint32 gasLimit) VRFConsumerBaseV2Plus(vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subId;
        i_gasLimit = gasLimit;
        s_RaffleState = RaffleState.OPEN;
    }

 

    function enterRaffle() external payable{
        // enter the raffle
        
        // require(msg.value >= i_entranceFee, NotEnoughETHEntered()); -> Not supported in 0.8.19 and less gas eficient than the below
        if (msg.value < i_entranceFee){
            revert Raffle__NotEnoughETHEntered();
        }

        if (s_RaffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Automation nodes call to see if the lottery is ready to be triggered.
     * @return upkeepNeeded  - true if it's time to start the lottery
     * @return performData - ignored
     */
    function checkUpkeep(bytes memory) public view returns(bool upkeepNeeded, bytes memory){
        bool timehasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = (s_RaffleState == RaffleState.OPEN);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timehasPassed && isOpen && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0");
    }


    function performUpkeep(bytes calldata) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded){
            revert Raffle__RequirementNotMet(address(this).balance, s_players.length, uint256(s_RaffleState));
        }

        s_RaffleState = RaffleState.CALCULATING;

        // Source: https://docs.chain.link/vrf/v2-5/getting-started
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest(
            {
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_gasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
            }
        );
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 /*requestId,*/, uint256[] calldata randomWords) internal override{
        uint256 indexofWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexofWinner];

        s_recentWinner = recentWinner;
        s_players = new address payable[](0);

        s_RaffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);


        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success){
            revert Raffle__TransferFailed();
        }

    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_RaffleState;
    }

    function getPlayer(uint256 indexofPlayer) external view returns (address) {
        return s_players[indexofPlayer];
    }

    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address) {
        return s_recentWinner;
    }
}