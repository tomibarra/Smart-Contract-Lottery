// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script
{

    struct NetworkConfig 
    {

        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 keyHash;
        uint64 subscription_id;
        uint32 callBackGasLimit;
        address link;
        uint256 deployerKey;
    }
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;

    constructor()
    {
        if(block.chainid == 11155111)
        {
            activeNetworkConfig = getSepoliaEthConfig();
        }
        else 
        {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }


    function getSepoliaEthConfig() public view returns(NetworkConfig memory)
    {
        return NetworkConfig
        (
            {
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscription_id: 0, //Update later with subId
                callBackGasLimit: 50000,
                link : 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("PRIVATE_KEY")
            }
        );
    }

    //Do another function but with anvil
    function getOrCreateAnvilConfig() public returns(NetworkConfig memory)
    {
        if(activeNetworkConfig.vrfCoordinator != address(0))
        {
            return activeNetworkConfig;
        }
        //Use mock contracts from VRF
        uint96 baseFee = 0.25 ether; // 0,25 LINK
        uint96 gasPriceLink = 1e9;  // 1 gwei LINK

        vm.startBroadcast();

        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(baseFee,gasPriceLink);
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return NetworkConfig
        (
            {
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinatorV2Mock),
                keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscription_id: 0, //Our script will add this
                callBackGasLimit: 50000,
                link: address(link),
                deployerKey: DEFAULT_ANVIL_KEY
            }
        );
 



    }

}