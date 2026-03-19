// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {AMMHook} from "../src/AMMHook.sol";

/// @title AMMHookScript — Deploys the DeltaShield AMM Hook
/// @notice Mines a CREATE2 salt so the deployed address encodes the correct hook flag bits,
///         then deploys the AMMHook contract.
/// @dev Usage:
///   Test: forge script script/AMMHook.s.sol:AMMHookScript --rpc-url <RPC> --chain-id <ID>
///   Live: forge script script/AMMHook.s.sol:AMMHookScript --rpc-url <RPC> --chain-id <ID> --broadcast --verify
contract AMMHookScript is Script {
    /// @dev Foundry deterministic CREATE2 deployer
    address internal constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    /// @dev PoolManager address — replace per target chain.
    /// Current: Eth Sepolia (https://docs.uniswap.org/contracts/v4/deployments)
    IPoolManager internal constant POOLMANAGER = IPoolManager(address(0xE03A1074c86CFeDd5C142C4F04F1a1536e203543));

    function setUp() public {}

    function run() public {
        // Hook flags must match getHookPermissions() in AMMHook.sol
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );

        bytes memory constructorArgs = abi.encode(POOLMANAGER);

        // Mine a salt that produces a hook address with the correct flag bits
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(AMMHook).creationCode, constructorArgs);

        console.log("Deploying AMMHook to:", hookAddress);

        vm.broadcast();
        AMMHook ammHook = new AMMHook{salt: salt}(POOLMANAGER);

        require(address(ammHook) == hookAddress, "AMMHookScript: hook address mismatch");

        console.log("AMMHook deployed successfully at:", address(ammHook));
    }
}
