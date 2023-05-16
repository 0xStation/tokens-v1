// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// interfaces
import {IBadge} from "./IBadge.sol";
import {ITokenGuard} from "src/lib/guard/ITokenGuard.sol";
import {IRenderer} from "../lib/renderer/IRenderer.sol";
// contracts
import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import {ERC1155Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {Permissions} from "../lib/Permissions.sol";
import {Batch} from "../lib/Batch.sol";
import {BadgeStorageV0} from "./storage/BadgeStorageV0.sol";

contract Badge is IBadge, UUPSUpgradeable, ERC1155Upgradeable, Permissions, Batch, BadgeStorageV0 {
    /// @notice Initializes the ERC1155 token.
    /// @param newOwner The address to transfer ownership to.
    /// @param newRenderer The address of the renderer.
    /// @param newName The name of the token.
    /// @param newSymbol The symbol of the token.
    function init(address newOwner, address newRenderer, string calldata newName, string calldata newSymbol)
        public
        initializer
    {
        _transferOwnership(newOwner);
        _updateRenderer(newRenderer);
        name = newName;
        symbol = newSymbol;
    }

    /// @notice Initializes the ERC1155 token and makes other setup state changes.
    /// @param newOwner The address to transfer ownership to.
    /// @param newRenderer The address of the renderer.
    /// @param newName The name of the token.
    /// @param newSymbol The symbol of the token.
    /// @param setupCalls The calls to make on other functions to initialize additional state.
    function initAndSetup(
        address newOwner,
        address newRenderer,
        string calldata newName,
        string calldata newSymbol,
        bytes[] calldata setupCalls
    ) external {
        init(newOwner, newRenderer, newName, newSymbol);
        batch(false, setupCalls); // non-atomic batch, setup calls allowed to fail to not undo state changes made by init
    }

    function _authorizeUpgrade(address newImplementation) internal override permitted(Operation.UPGRADE) {}

    function uri(uint256 id) public view override returns (string memory) {
        return IRenderer(renderer).tokenURI(id);
    }

    function updateRenderer(address _renderer) external permitted(Operation.RENDER) returns (bool success) {
        _updateRenderer(_renderer);
        return true;
    }

    function _updateRenderer(address _renderer) internal {
        renderer = _renderer;
        emit UpdatedRenderer(_renderer);
    }

    function mintTo(address recipient, uint256 tokenId, uint256 amount)
        external
        permitted(Operation.MINT)
        returns (bool success)
    {
        _mint(recipient, tokenId, amount, "");
        return true;
    }

    function burnFrom(address account, uint256 tokenId, uint256 amount)
        external
        permitted(Operation.BURN)
        returns (bool success)
    {
        _burn(account, tokenId, amount);
        return true;
    }

    function burn(uint256 tokenId, uint256 amount) external returns (bool success) {
        _burn(msg.sender, tokenId, amount);
        return true;
    }

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    ) internal override {
        address guard;
        // MINT
        if (from == address(0)) {
            guard = guardOf[Operation.MINT];
        }
        // BURN
        else if (to == address(0)) {
            guard = guardOf[Operation.BURN];
        }
        // TRANSFER
        else {
            guard = guardOf[Operation.TRANSFER];
        }

        require(
            guard != MAX_ADDRESS
                && (guard == address(0) || ITokenGuard(guard).isAllowed(operator, from, to, ids, amounts)),
            "NOT_ALLOWED"
        );
    }
}
