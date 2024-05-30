// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test
{
    /*Events */
    event Raffle__playerAdded(address indexed player);

    Raffle raffle;
    HelperConfig  helperConfig; 
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint64 subscription_id;
    uint32 callBackGasLimit;
    address link;

    
    address public PLAYER = makeAddr("player");
    uint256  public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external
    {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            keyHash,
            subscription_id,
            callBackGasLimit,
            link,
            
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view
    {
        assert(raffle.getRaffleState()== Raffle.RaffleStates.OPEN);
    }

    //////////////////// 
    // EnterRaffle    //
    //////////////////// 
    
    function testRaffleRevertsWhenYouDontPayEnough() public
    {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__InsufficientFee.selector);
        raffle.enterRaffle();
    }
    function testRaffleRecordsWhenPlayerEnter() public
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public
    {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle__playerAdded(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function cantEnterWhenRaffleIsCalc() public
    {
        //Arrange
        //Act 
        //assert
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee};   

    }

    /////////////////////////
    //// checkUpkeep  ///////
    /////////////////////////




    function testFalseIfNoBalance() public
    {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upKeepNeeded);


    }

    function testFalseIfRaffleNotOpen() public 
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        //assert
        assert(!upKeepNeeded);
       
        
    }
    
    //checkUpkeepReturnsFalseIfEnoughTimeHasntPassed
    //checkUpkeepReturnsTrueIfParametersAreGood

    function testRetFalseIfEnoughTimeHasNotPassed() public
    {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();



        //Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!upKeepNeeded);
    }

    function testRetTrueIfAllIsGood() public
    {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(upKeepNeeded);
    }

    /////////////////////////////
    ////// performUpkeep   /////
    ////////////////////////////


    function testOnlyRunIfCheckUpkeepIsTrue() public
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
       
    }

    function testRevertsIfCheckUpKeepIsFalse()  public 
    {
        uint256 currentBalance = 0;
        uint256 playersLength = 0;
        uint256 raffleState = 0;
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__NoUpkeepNeeded.selector, currentBalance,playersLength,raffleState));
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() 
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
       
       
       _; 
    }
    function testUpdatesRaffleStateAndEmitsRequestId()  public raffleEnteredAndTimePassed
    {
       vm.recordLogs();
       raffle.performUpkeep("");
       Vm.Log[] memory entries = vm.getRecordedLogs(); 
       bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleStates rStates = raffle.getRaffleState();

       assert(uint256(requestId) > 0);
       assert(uint256(rStates) == 1);
    }

    //////////////////////////////
    ///// fullFillRandomWords ////
    //////////////////////////////

    modifier skipFork 
    {
       if(block.chainid !=31337)  
       {
        return;
       }
       _;
    }

    function testcanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEnteredAndTimePassed skipFork
    {
       vm.expectRevert("nonexistent request"); 
       VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId,address (raffle));
    }
    
    function testPicksAwinnerResetsAndSendMoney() public raffleEnteredAndTimePassed skipFork
    {
        //Arrange, hacer que 5 jugadores mas, entren al raffle
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for( uint256 i = startingIndex; i < (startingIndex + additionalEntrants); i++)
        {
            console.log("Indice: ",i);
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
         
        uint256 price = entranceFee * (additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); 
        bytes32 requestId = entries[1].topics[1];
        uint256 previousLastTimestamp = raffle.getLastTimestamp();

        //Act 
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId),address(raffle));


        //Assert
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getPlayersLength() == 0);
        assert(previousLastTimestamp < raffle.getLastTimestamp());
        assert(raffle.getRecentWinner().balance ==(STARTING_USER_BALANCE + price - entranceFee));

    }

}
