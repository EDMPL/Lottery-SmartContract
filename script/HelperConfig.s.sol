// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    /* VRF Mock Values */
    uint96 MOCK_BASE_FEE = 0.25 ether; // 0.25 LINK
    uint96 MOCK_GAS_PRICE = 1e9; // 0.000000001 LINK per gas
    int256 WEI_PER_UNIT = 4e15; // 0.004 ETH/Link

    uint256 public constant ETH_SEPOLIA_TESTNET_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    }

contract HelperConfig is CodeConstants, Script{
    error HelperConfig__InvalidChainId();

    struct NetworkConfig{
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public activeNetworkConfig;
    mapping (uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_TESTNET_CHAIN_ID] = getSepoliaNetwork();
    }

    function getConfigbyChainId(uint256 chainId) public returns (NetworkConfig memory){
        if (networkConfigs[chainId].vrfCoordinator != address(0)){
            return networkConfigs[chainId];
        }
        else if (chainId == LOCAL_CHAIN_ID){
            return getOrCreateAnvilNetwork();
        }
        else{
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory){
        return getConfigbyChainId(block.chainid);
    }

    function getSepoliaNetwork() public pure returns(NetworkConfig memory){
        return NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30, //seconds
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, // https://docs.chain.link/vrf/v2/subscription/supported-networks
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // https://docs.chain.link/vrf/v2/subscription/supported-networks
            subscriptionId: 0, // Will be set up later
            callbackGasLimit: 500000, // 500,000 gas
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateAnvilNetwork() public returns(NetworkConfig memory){
        if (activeNetworkConfig.vrfCoordinator != address(0)){
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, WEI_PER_UNIT);
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        activeNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30, //seconds
            vrfCoordinator: address(vrfCoordinatorMock), // mockVrfCoordinator
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // does not mater
            subscriptionId: 0, // subId
            callbackGasLimit: 500000, // 500,000 gas
            link: address(link)
        });
        return activeNetworkConfig;
    }


    // function run() public {}
}