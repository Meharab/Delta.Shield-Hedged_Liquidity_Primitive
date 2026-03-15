// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

/// @dev Replace import with the desired hook
import {AMMHook} from "../src/AMMHook.sol";

// Example:
// Live run: forge script script/AMMHook.s.sol:AMMHookScript --rpc-url https://sepolia.base.org --chain-id 84532 --broadcast --verify
// Test run: forge script script/AMMHook.s.sol:AMMHookScript --rpc-url https://sepolia.base.org --chain-id 84532
//           ^----------^ ^--------------------------------^ ^--------------------------------^ ^--------------^

/// @notice Mines the address and deploys the AMMHook.sol Hook contract
contract AMMHookScript is Script {
    // https://getfoundry.sh/guides/deterministic-deployments-using-create2/#getting-started
    address internal constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    /// @dev Replace with the desired PoolManager on its corresponding chain
    /// @dev For mainnet, this is the same address as the CREATE2_DEPLOYER
    /// https://docs.uniswap.org/contracts/v4/deployments#base-sepolia-84532
    IPoolManager internal constant POOLMANAGER = IPoolManager(address(0xE03A1074c86CFeDd5C142C4F04F1a1536e203543)); // Eth Sepolia

    function setUp() public {}

    function run() public {
        // uint privateKey = vm.envUint('PRIVATE_KEY');

        // Hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.AFTER_ADD_LIQUIDITY_FLAG | 
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );

        bytes memory constructorArgs = abi.encode(POOLMANAGER);

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(AMMHook).creationCode, constructorArgs);

        // vm.startBroadcast(privateKey);

        // Deploy the hook using CREATE2
        vm.broadcast();
        AMMHook ammHook = new AMMHook{salt: salt}(IPoolManager(POOLMANAGER));
        require(address(ammHook) == hookAddress, "AMMHookScript: hook address mismatch");

        // vm.stopBroadcast();
    }
}