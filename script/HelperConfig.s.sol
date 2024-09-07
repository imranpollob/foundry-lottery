// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UNIT_LINK = 4e15; // LINK to ETH price

    address public FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    // Chain ID's
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig_InvalidChainId();

    struct NetworkConfig {
        // Raffle constructor parameters
        uint256 subscriptionId;
        bytes32 keyHash;
        uint256 interval;
        uint256 entryFee;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2_5;
        // extra params
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    // store network configs in a mapping
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
        // we will create the local config from calling getOrCreateAnvilEthConfig() function
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory mainnetNetworkConfig) {
        // https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-mainnet
        mainnetNetworkConfig = NetworkConfig({
            subscriptionId: 0, // if left 0 then our script will create one
            keyHash: 0xc6bf2e7b88e5cfbb4946ff23af846494ae1f3c65270b79ee7876c9aa99d3d45f,
            interval: 30, // 30 seconds
            entryFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D // not sure what it is
        });
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
        // https://docs.chain.link/vrf/v2-5/supported-networks#sepolia-testnet
        sepoliaNetworkConfig = NetworkConfig({
            subscriptionId: 0, // if left 0 then our script will create one
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            interval: 30, // 30 seconds
            entryFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D // not sure what it is
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // check if there is already a local network config
        if (localNetworkConfig.vrfCoordinatorV2_5 != address(0)) return localNetworkConfig;

        console2.log(unicode"⚠️ You have deployed a mock conract!");
        console2.log("Make sure this was intentional");

        vm.startBroadcast();

        // VRFCoordinatorV2_5Mock => constructor(uint96 _baseFee, uint96 _gasPrice, int256 _weiPerUnitLink)
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);

        LinkToken linkToken = new LinkToken();

        uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            subscriptionId: subscriptionId,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // doesn't matter
            interval: 30, // 30 seconds
            entryFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: address(vrfCoordinatorV2_5Mock),
            link: address(linkToken),
            account: FOUNDRY_DEFAULT_SENDER
        });

        // send ether to the default sender
        vm.deal(localNetworkConfig.account, 100 ether);

        return localNetworkConfig;
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinatorV2_5 != address(0)) return networkConfigs[chainId];
        else if (chainId == LOCAL_CHAIN_ID) return getOrCreateAnvilEthConfig();
        else revert HelperConfig_InvalidChainId();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        networkConfigs[chainId] = networkConfig;
    }
}
