// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import {Ownable} from "mage/access/ownable/Ownable.sol";
import {Initializable} from "mage/lib/initializable/Initializable.sol";
import {IERC721Mage} from "mage/cores/ERC721/interface/IERC721Mage.sol";

import {IBadgesFactory} from "./IBadgesFactory.sol";
import {BadgesFactoryStorage} from "./BadgesFactoryStorage.sol";

contract BadgesFactory is Initializable, Ownable, UUPSUpgradeable, IBadgesFactory {
    /*============
        SET UP
    ============*/

    constructor() Initializable() {}

    function initialize(address badgesImpl_, address owner_) external initializer {
        _updateBadgesImpl(badgesImpl_);
        _transferOwnership(owner_);
    }

    function badgesImpl() public view returns (address) {
        return BadgesFactoryStorage.layout().badgesImpl;
    }

    function setBadgesImpl(address newImpl) external onlyOwner {
        _updateBadgesImpl(newImpl);
    }

    function _updateBadgesImpl(address newImpl) internal {
        if (newImpl == address(0)) revert InvalidImplementation();
        BadgesFactoryStorage.Layout storage layout = BadgesFactoryStorage.layout();
        layout.badgesImpl = newImpl;
        emit BadgesUpdated(newImpl);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /*============
        CREATE
    ============*/

    function create(address owner, string memory name, string memory symbol, bytes calldata initData)
        public
        returns (address badges)
    {
        badges = address(new ERC1967Proxy(badgesImpl(), bytes("")));
        emit BadgesCreated(badges); // put BadgesCreated before initialization events for indexer convenience
        // initializer relies on self-delegatecall which does not work when passed through a proxy's constructor
        // make a separate call to initialize after deploying new proxy
        IERC721Mage(badges).initialize(owner, name, symbol, initData);
    }
}