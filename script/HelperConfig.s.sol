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
        address account;
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
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-sepolia-testnet
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-sepolia-testnet
            subscriptionId: 114985517424144402947386292587658918584865960761088278321678044314686071095947, //  Setup from VRF Chainlink Website
            callbackGasLimit: 500000, // 500,000 gas
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xc7B59145C84361b8F366C1750B1ab080dBF01deB
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
            link: address(link),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 // DEFAULT SENDER FROM forge-std/Base.sol
        });
        return activeNetworkConfig;
    }


    // function run() public {}
}