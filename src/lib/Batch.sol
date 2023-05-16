// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @notice Batch calling mechanism on the implementing contract
/// @dev inspired by BoringBatchable: https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/BoringBatchable.sol
abstract contract Batch {
    function batch(bool atomic, bytes[] calldata calls) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success,) = address(this).delegatecall(calls[i]);
            require(success || !atomic, "BATCH_FAIL");
        }
    }
}
