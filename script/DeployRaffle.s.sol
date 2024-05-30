// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";


contract DeployRaffle is Script
{
    function run() external returns(Raffle, HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig();
        (
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint64 subscription_id,
        uint32 callBackGasLimit,
        address link,
        uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if(subscription_id == 0)
        {
            //Create subscription id
            CreateSubscription createSubscription = new CreateSubscription();
            subscription_id = createSubscription.createSubscription(vrfCoordinator, deployerKey);
             //Fund with the subscription id 
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscription_id, link,deployerKey);

        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(entranceFee,interval, vrfCoordinator,keyHash,subscription_id,callBackGasLimit);
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle),vrfCoordinator,subscription_id,deployerKey);        




        return (raffle, helperConfig);
    }
}
