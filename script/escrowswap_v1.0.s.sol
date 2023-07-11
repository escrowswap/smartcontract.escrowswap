// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "../src/escrowswap_v1.0.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // GOERLI
        vm.createSelectFork(vm.rpcUrl("goerli"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapGOERLI = new EscrowswapV1(vm.envAddress("W_GOERLI"));
        vm.stopBroadcast();

        // SEPOLIA
        vm.createSelectFork(vm.rpcUrl("sepolia"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapSEPOLIA = new EscrowswapV1(vm.envAddress("W_SEPOLIA"));
        vm.stopBroadcast();

        // MAINNET
        vm.createSelectFork(vm.rpcUrl("mainnet"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapMAINNET = new EscrowswapV1(vm.envAddress("W_MAINNET"));
        vm.stopBroadcast();

        // POLYGON
        vm.createSelectFork(vm.rpcUrl("polygon"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapPOLYGON = new EscrowswapV1(vm.envAddress("W_POLYGON"));
        vm.stopBroadcast();

        // POLYGON MUMBAI
        vm.createSelectFork(vm.rpcUrl("mumbai"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapMUMBAI = new EscrowswapV1(vm.envAddress("W_POLYGON_MUMBAI"));
        vm.stopBroadcast();

        // BSC
        vm.createSelectFork(vm.rpcUrl("bsc"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapBSC = new EscrowswapV1(vm.envAddress("W_BSC"));
        vm.stopBroadcast();

        // BSC TEST
        vm.createSelectFork(vm.rpcUrl("bsc-testnet"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapBSCTEST = new EscrowswapV1(vm.envAddress("W_BSC_TESTNET"));
        vm.stopBroadcast();

        // OPTIMISM
        vm.createSelectFork(vm.rpcUrl("optimism"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapOPTIMISM = new EscrowswapV1(vm.envAddress("W_OPTIMISM"));
        vm.stopBroadcast();

        // OPTIMISM TEST
        vm.createSelectFork(vm.rpcUrl("optimism-goerli"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapOPTIMISMTEST = new EscrowswapV1(vm.envAddress("W_OPTIMISM_TESTNET"));
        vm.stopBroadcast();

        // ARBITRUM
        vm.createSelectFork(vm.rpcUrl("arbitrum"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapARBITRUM = new EscrowswapV1(vm.envAddress("W_ARBITRUM"));
        vm.stopBroadcast();

        // ARBITRUM GOERLI
        vm.createSelectFork(vm.rpcUrl("arbitrum-goerli"));
        vm.startBroadcast(deployerPrivateKey);
        EscrowswapV1 escrowswapARBITRUM = new EscrowswapV1(vm.envAddress("W_ARBITRUM_TESTNET"));
        vm.stopBroadcast();
    }
}