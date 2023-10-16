// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library AccountGroupStorage {
    bytes32 internal constant SLOT = keccak256(abi.encode(uint256(keccak256("groupos.AccountGroup")) - 1));

    struct Layout {
        mapping(uint64 => address) accountOf;
        mapping(uint64 => address) initializerOf;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }
}
