// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC721Mage} from "mage/cores/ERC721/interface/IERC721Mage.sol";
import {IPermissions} from "mage/access/permissions/interface/IPermissions.sol";
import {Operations} from "mage/lib/Operations.sol";
// module utils
import {ModuleSetup} from "src/v2/lib/module/ModuleSetup.sol";
import {ModulePermit} from "src/v2/lib/module/ModulePermit.sol";
import {ModuleFee} from "src/v2/lib/module/ModuleFee.sol";

/// @title Station Network FreeMintModuleV3 Contract
/// @author symmetry (@symmtry69), frog (@0xmcg), 👦🏻👦🏻.eth
/// @dev Provides a modular contract to handle collections who wish for their membership mints to be
/// free of charge, save for Station Network's base fee

contract FreeMintModule is ModuleSetup, ModulePermit, ModuleFee {
    /*=============
        STORAGE
    =============*/

    /// @dev collection => permits disabled, permits are enabled by default
    mapping(address => bool) internal _disablePermits;

    /*============
        EVENTS
    ============*/

    event SetUp(address indexed collection, bool indexed disablePermits);

    /*============
        CONFIG
    ============*/

    /// @param _newOwner The owner of the ModuleFeeV2, an address managed by Station Network
    /// @param _feeManager The FeeManager's address
    constructor(address _newOwner, address _feeManager) ModulePermit() ModuleFee(_newOwner, _feeManager) {}

    /// @dev Function to set up and configure a new collection
    /// @param collection The new collection to configure
    /// @param disablePermits A boolean to represent whether this collection will repeal or support grant functionality
    function setUp(address collection, bool disablePermits) public canSetUp(collection) {
        if (_disablePermits[collection] != !disablePermits) {
            _disablePermits[collection] = !disablePermits;
        }
        emit SetUp(collection, disablePermits);
    }

    /// @dev convenience function for setting up when creating collections, relies on auth done in public setUp
    function setUp(bool disablePermits) external {
        setUp(msg.sender, disablePermits);
    }

    /*==========
        MINT
    ==========*/

    /// @dev Function to mint a single collection token to the caller, ie a user
    function mint(address collection) external payable {
        _batchMint(collection, msg.sender, 1);
    }

    /// @dev Function to mint a single collection token to a specified recipient
    function mintTo(address collection, address recipient) external payable {
        _batchMint(collection, recipient, 1);
    }

    /// @dev Function to mint collection tokens in batches to the caller, ie a user
    /// @notice returned tokenId range is inclusive
    function batchMint(address collection, uint256 amount) external payable {
        _batchMint(collection, msg.sender, amount);
    }

    /// @dev Function to mint collection tokens in batches to a specified recipient
    /// @notice returned tokenId range is inclusive
    function batchMintTo(address collection, address recipient, uint256 amount) external payable {
        _batchMint(collection, recipient, amount);
    }

    /*===============
        INTERNALS
    ===============*/

    /// @dev Internal function to which all external user + client facing batchMint functions are routed.
    /// @param collection The token collection to mint from
    /// @param recipient The recipient of successfully minted tokens
    /// @param quantity The quantity of tokens to mint
    function _batchMint(address collection, address recipient, uint256 quantity)
        internal
        usePermits(_encodePermitContext(collection))
        returns (uint256 startTokenId, uint256 endTokenId)
    {
        require(quantity > 0, "ZERO_AMOUNT");

        // take baseFee (variableFee == 0 when price == 0)
        _registerFeeBatch(collection, address(0x0), recipient, quantity, 0);

        // no revenue transfer to collection payoutAddress because this is a free mint

        // perform mints
        IERC721Mage(collection).mintTo(recipient, quantity);
    }

    /*=============
        PERMITS
    =============*/

    function _encodePermitContext(address collection) internal pure returns (bytes memory context) {
        return abi.encode(collection);
    }

    function _decodePermitContext(bytes memory context) internal pure returns (address collection) {
        return abi.decode(context, (address));
    }

    function signerCanPermit(address signer, bytes memory context) public view override returns (bool) {
        address collection = _decodePermitContext(context);
        return IPermissions(collection).hasPermission(Operations.MINT_PERMIT, signer);
    }

    function requirePermits(bytes memory context) public view override returns (bool) {
        address collection = _decodePermitContext(context);
        return !_disablePermits[collection];
    }
}
