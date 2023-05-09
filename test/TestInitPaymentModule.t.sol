// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/lib/renderer/Renderer.sol";
import "../src/membership/Membership.sol";
import "../src/membership/MembershipFactory.sol";
import "../src/modules/FixedETHPurchaseModule.sol";

// designed to make sure the payment module itself is working properly.
// different than TestPaymentModule which is designed to test if payment module can be added to a membership
// and work correctly with the membership.
contract PaymentModuleInitTest is Test {
  FixedETHPurchaseModule paymentModule;

  function setUp() public {
    paymentModule = new FixedETHPurchaseModule();
  }

  function test_add_address() public {
    paymentModule.setup(address(0), address(0), 1);
    // nothing exploded!
  }
}
