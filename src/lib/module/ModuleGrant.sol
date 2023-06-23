// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Permissions} from "src/lib/Permissions.sol";
import {NonceBitMap} from "src/lib/NonceBitMap.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

abstract contract ModuleGrant is NonceBitMap {
    struct Grant {
        address sender;
        uint48 expiration;
        uint256 nonce;
        bytes data;
        bytes signature;
    }

    /*=============
        STORAGE
    =============*/

    // signatures
    bytes32 private constant GRANT_TYPE_HASH =
        keccak256(abi.encode("Grant(address sender,uint48 expiration,uint256 nonce,bytes data)"));
    bytes32 private constant DOMAIN_TYPE_HASH =
        keccak256(abi.encode("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));
    bytes32 private constant NAME_HASH = keccak256(abi.encode("GroupOS"));
    bytes32 private constant VERSION_HASH = keccak256(abi.encode("0.0.1"));
    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;
    uint256 internal immutable INITIAL_CHAIN_ID;

    // authentication handoff
    address private constant UNVERIFIED = address(1);
    uint256 private constant UNLOCKED = 1;
    uint256 private constant LOCKED = 2;
    address private grantSigner = UNVERIFIED;
    uint256 private lock = UNLOCKED;

    constructor() {
        INITIAL_DOMAIN_SEPARATOR = _domainSeparator();
        INITIAL_CHAIN_ID = block.chainid;
    }

    /*====================
        CORE UTILITIES
    ====================*/

    /// @notice authenticate module functions for collections with grants and reentrancy protection
    modifier onlyGranted(address collection) {
        // grant authentication
        address signer = grantSigner;
        require(
            // grants unenforced or
            !grantsEnforced(collection)
            // signer has permission to grant
            // signer checked as UNVERIFIED first for gas opt and to prevent subtle attack vector of permitting address(1) side effects
            || (signer != UNVERIFIED && Permissions(collection).hasPermission(signer, Permissions.Operation.GRANT)),
            "UNAUTHORIZED"
        );
        // reentrancy protection
        require(lock == UNLOCKED, "REENTRANCY");
        // lock
        lock = LOCKED;
        // function execution
        _;
        // unlock
        lock = UNLOCKED;
        // reset signer
        grantSigner = UNVERIFIED;
    }

    /// @notice support calling a function with a grant as the sole permitted sender
    function callWithGrant(uint48 expiration, uint256 nonce, bytes calldata data, bytes calldata signature) external {
        _callWithGrant(Grant(msg.sender, expiration, nonce, data, signature));
    }

    /// @notice support calling a function with a grant with public access
    function publicCallWithGrant(uint48 expiration, uint256 nonce, bytes calldata data, bytes calldata signature)
        external
    {
        _callWithGrant(Grant(address(0), expiration, nonce, data, signature));
    }

    /// @notice virtual to enable modules to customize storage packing of grant ignoring status
    function grantsEnforced(address collection) public view virtual returns (bool) {
        return true; // should override implementation
    }

    /*=====================
        PRIVATE HELPERS
    =====================*/

    /// @notice authenticate grant and make a self-call
    /// @dev can only be used on functions that are protected with onlyGranted
    function _callWithGrant(Grant memory grant) private {
        // recover signer from grant
        grantSigner = _recoverSigner(grant);
        // use nonce
        _useNonce(grantSigner, grant.nonce);
        // make authenticated call
        (bool success,) = address(this).delegatecall(grant.data);
        require(success, "FAILED");
        // enforce signer reset to guarantee modifier usage and limit side effects of calling unprotected functions
        require(grantSigner == UNVERIFIED, "CALL_NOT_PROTECTED");
    }

    /// @notice Mint tokens using a signature from a permitted minting address
    function _recoverSigner(Grant memory grant) private returns (address signer) {
        // hash grant values
        bytes32 valuesHash =
            keccak256(abi.encode(GRANT_TYPE_HASH, grant.sender, grant.expiration, grant.nonce, grant.data));
        // hash domain with grant values
        bytes32 grantHash = ECDSA.toTypedDataHash(
            INITIAL_CHAIN_ID == block.chainid ? INITIAL_DOMAIN_SEPARATOR : _domainSeparator(), valuesHash
        );
        // recover signer
        signer = ECDSA.recover(grantHash, grant.signature);
    }

    function _domainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPE_HASH, NAME_HASH, VERSION_HASH, block.chainid, address(this)));
    }
}
