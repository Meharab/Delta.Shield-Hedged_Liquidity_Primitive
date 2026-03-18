// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.26;

import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";

// @title MockEventGenarator: A simple contract to emit HedgeRequired events for testing
// @dev This contract allows us to simulate the emission of HedgeRequired events for "TESTNET", which can be used to test the Reactive Automation Layer without needing to interact with a real AMM or Uniswap v4 pool as it's extreamly hard to simulate pool and hook on the testnet. You can deploy this contract on the origin chain and call the emitHedgeRequired function with different parameters to test how the AutomationController reacts to various scenarios.
// @dev Note: In local testing, try not to use this contract.
contract MockEventGenarator {
    event HedgeRequired(
        uint256 indexed poolId,
        int256 delta,
        uint160 sqrtPriceX96,
        uint256 timestamp
    );

    function emitHedgeRequired(
        uint256 _poolId,
        int256 _delta,
        uint160 _sqrtPriceX96
    ) external {
        emit HedgeRequired(_poolId, _delta, _sqrtPriceX96, block.timestamp);
    }
}
// @dev you can deploy the MockEventGenarator with cast:
// forge create --broadcast --rpc-url $ORIGIN_RPC --account $ACC  src/MockEventGenarator.sol:MockEventGenarator

// Example output
// Deployer: 0x55F710a5509f4a8a8fE8a41dF476e51daD401454
// Deployed to: 0x3059147Addf9914704BA655b8c1652DF27B89260
// Transaction hash: 0x275f3706ad629586d4168241bfe3eac49c76695d2f8f603e75fbde60d1e63a11

// Example  with cast:
/*
cast send $ORIGIN_ADDR --rpc-url $ORIGIN_RPC --account $ACC --value 0.001ether
Enter keystore password:

blockHash            0xe9105e512246aaf8777884bd550100f3d3acb82403a2d7831cfaa2746a14a9ce
blockNumber          10430723
contractAddress      
cumulativeGasUsed    6172570
effectiveGasPrice    1100009
from                 0x55F710a5509f4a8a8fE8a41dF476e51daD401454
gasUsed              29787
logs                 [{"address":"0x3059147addf9914704ba655b8c1652df27b89260","topics":["0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb","0x00000000000000000000000055f710a5509f4a8a8fe8a41df476e51dad401454","0x00000000000000000000000055f710a5509f4a8a8fe8a41df476e51dad401454","0x00000000000000000000000000000000000000000000000000038d7ea4c68000"],"data":"0x","blockHash":"0xe9105e512246aaf8777884bd550100f3d3acb82403a2d7831cfaa2746a14a9ce","blockNumber":"0x9f2903","blockTimestamp":"0x69b23dac","transactionHash":"0x2f167c3fb727280e8db30ebbf3690b1142f580aa798258cd245c797b1b541899","transactionIndex":"0x4e","logIndex":"0x82","removed":false}]
logsBloom            0x00000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000001000000000080000000000020000000000000000000000000000000000000000000000000000200000000000000000000000000000040000000000000000000000000000000400000000000000000008080000000000000000000000000000000000000000000000000000000000000000080000000000000000000000400000000000000000000000000
root                 
status               1 (success)
transactionHash      0x2f167c3fb727280e8db30ebbf3690b1142f580aa798258cd245c797b1b541899
transactionIndex     78
type                 2
blobGasPrice         
blobGasUsed          
to                   0x3059147Addf9914704BA655b8c1652DF27B89260
*/