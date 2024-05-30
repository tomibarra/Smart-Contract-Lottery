// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions 



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//Importar la interfazVRF
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";



/**
 * @title Smart Contract Lottery
 * @author tomiBarra
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */


contract Raffle is VRFConsumerBaseV2
{
    error Raffle__InsufficientFee();
    error Raffle__NotEnded();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__NoUpkeepNeeded(uint256 currentBalance, uint256 currentPlayers, RaffleStates raffleStates);
    /**Type declarations  */
    enum RaffleStates{OPEN, CALCULATING} //open es 0, calculating es 1, y si hay mas argumentos les pone su respectivo numero

    //Storage Variables
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    uint64 private immutable i_subscription_id;
    address payable[] private s_players;
    address private s_recentWinner;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 i_keyHash;
    uint256 private lastTimestamp;
    uint16 private constant REQUEST_CONFIRMATIONS=3;
    uint32 private constant NUM_WORDS = 1;
    uint32 private immutable i_callBackGasLimit;
    RaffleStates private s_raffleState;



    /*Eventos */
    event Raffle__playerAdded(address indexed player);
    event Raffle__winnerPicked(address indexed winner);
    event Raffle__requestedWinner(uint256 indexed requestId);


    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 keyHash, uint64 subscription_id, uint32 callBackGasLimit) VRFConsumerBaseV2(vrfCoordinator)
    {
        i_entranceFee = entranceFee;
        i_interval = interval;
        lastTimestamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_keyHash = keyHash;
        i_subscription_id = subscription_id;
        i_callBackGasLimit = callBackGasLimit;
        s_raffleState = RaffleStates.OPEN;
    }



    function enterRaffle()  external payable
    {
        if(msg.value < i_entranceFee)
        {
            revert Raffle__InsufficientFee();
        }
        if(s_raffleState != RaffleStates.OPEN)
        {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));//investigar bien porque se castea payable a msg sender
        emit Raffle__playerAdded(msg.sender);
        
    }

    /**
     * @dev This is the function that the chainlink automation nodes call to see if it's time to perform an upkeep
     * the following should be true to return true:
     * 1-the time interval has passed beetween raffle runs
     * 2-Raffle is in open state
     * 3-The contract has ETH(aka players)
     * 4-implicit the subscription is funded with link
     * 
     */
    function checkUpkeep(bytes memory /** checkData */) public view returns (bool upkeepNeeded, bytes memory)
    {
        bool timePassed = block.timestamp - lastTimestamp >= i_interval;
        bool raffleOpen = (s_raffleState == RaffleStates.OPEN);
        bool hasPlayers = s_players.length > 0;
        bool hasEth = address(this).balance > 0;
        if(timePassed && raffleOpen && hasPlayers && hasEth)
        {
            upkeepNeeded = true;
        }
        else
        {
            upkeepNeeded = false;     
            
        }
        return (upkeepNeeded, "0x0");
        
    }

    

    //1- numero aleatorio
    //2- usar ese numero para elegir un jugador
    //3- llamar automaticamente esta funcion para elegir ganador, el numero aleatorio se supone que se crea con chainlink
    function performUpkeep(bytes calldata) external 
    {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if(!upKeepNeeded)
        {
            revert Raffle__NoUpkeepNeeded(address(this).balance, s_players.length,s_raffleState);
        }
        //chequear si terminó la votacion , con block timestamp
        if((block.timestamp - lastTimestamp) < i_interval)
        {
            revert Raffle__NotEnded();
        }
        //alterar el estado
        s_raffleState = RaffleStates.CALCULATING;
        //Get random number con chainlink 
        uint256 requestId =  i_vrfCoordinator.requestRandomWords(i_keyHash, i_subscription_id, REQUEST_CONFIRMATIONS, i_callBackGasLimit, NUM_WORDS);
        
        emit Raffle__requestedWinner(requestId);

        
    }


    function fulfillRandomWords(uint256 /*requestId*/, uint256[] memory randomWords) internal override
    {
      //necesito usar modulo %, modular por el numero de participantes
       uint256 indexOfWinner = randomWords[0] % s_players.length; 
       address payable winner = s_players[indexOfWinner];
       s_recentWinner = winner;
       s_raffleState = RaffleStates.OPEN;

       //Resetear el array para comenzar otra
       s_players = new address payable[](0);
       lastTimestamp = block.timestamp;

      //pagarle al ganador 
      (bool success, ) = winner.call{value: address(this).balance}("");
      if(!success)
      {
        revert Raffle__TransferFailed();
      }
      emit Raffle__winnerPicked(winner);

    }
    /**Getter Function */
    function getEntranceFee() external view returns(uint256)
    {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleStates)
    {
        return s_raffleState;
    }


    function getPlayer(uint256 indexOfPlayer) external view returns (address)
    {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns(address)
    {
        return s_recentWinner;
    }

    function getPlayersLength() external view returns(uint256)
    {
        return s_players.length;
    }
    
    function getLastTimestamp() external view returns(uint256)
    {
        return lastTimestamp;
    }

}