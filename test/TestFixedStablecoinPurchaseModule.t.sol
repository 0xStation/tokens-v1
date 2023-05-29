// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/lib/renderer/Renderer.sol";
import {Membership} from "../src/membership/Membership.sol";
import "../src/membership/MembershipFactory.sol";
import "../src/modules/FixedStablecoinPurchaseModule.sol";
import {FakeERC20} from "./utils/FakeERC20.sol";

contract PaymentModuleTest is Test {
    address public owner = address(123);
    address public paymentReciever = address(456);
    address public membershipFactory;
    address public rendererImpl;
    address public membershipImpl;
    address public membershipInstance;
    Membership public membershipContract;
    address public fixedStablecoinPurchaseModuleImpl;
    FixedStablecoinPurchaseModule public paymentModule;

    address public fakeUSDCImpl;
    address public fakeDAIImpl;
    uint256 fee = 0.0007 ether;
    uint256 BASE_BALANCE = 1000;

    function setUp() public {
        startHoax(owner);
        rendererImpl = address(new Renderer(owner, "https://tokens.station.express"));
        membershipImpl = address(new Membership());
        membershipFactory = address(new MembershipFactory(membershipImpl, owner));
        fixedStablecoinPurchaseModuleImpl = address(new FixedStablecoinPurchaseModule(owner, fee, "USD", 2));
        paymentModule = FixedStablecoinPurchaseModule(fixedStablecoinPurchaseModuleImpl);
        fakeUSDCImpl = address(new FakeERC20(6));
        fakeDAIImpl = address(new FakeERC20(18));
        membershipInstance =
            MembershipFactory(membershipFactory).create(owner, rendererImpl, "Friends of Station", "FRIENDS");
        membershipContract = Membership(membershipInstance);

        Permissions.Operation[] memory operations = new Permissions.Operation[](1);
        operations[0] = Permissions.Operation.MINT;
        membershipContract.permit(fixedStablecoinPurchaseModuleImpl, membershipContract.permissionsValue(operations));
        membershipContract.updatePaymentCollector(paymentReciever);

        // give account fake DAI + fake USDC
        // 1000 USD equivalent
        FakeERC20(fakeDAIImpl).mint(owner, BASE_BALANCE * 10 ** 18);
        FakeERC20(fakeDAIImpl).approve(fixedStablecoinPurchaseModuleImpl, BASE_BALANCE * 10 ** 18);
        FakeERC20(fakeUSDCImpl).mint(owner, BASE_BALANCE * 10 ** 6);
        FakeERC20(fakeUSDCImpl).approve(fixedStablecoinPurchaseModuleImpl, BASE_BALANCE * 10 ** 6);
        vm.stopPrank();
    }

    // 1. token exists but is not enabled for collection
    // 2. the token doesnt exist at the module level
    function test_stablecoinEnabled() public {
        uint256 defaultPrice = 1;
        startHoax(owner);
        // 1. add fakeUSDCImpl and fakeDAIImpl to payment module
        paymentModule.append(fakeUSDCImpl);
        paymentModule.append(fakeDAIImpl);
        // 2. create address array of tokens we want enabled
        address[] memory enabledTokens = new address[](2);
        enabledTokens[0] = fakeUSDCImpl;
        enabledTokens[1] = fakeDAIImpl;
        // 3. setup payment module with enabled tokens for membership instance
        paymentModule.setup(membershipInstance, defaultPrice, paymentModule.enabledTokensValue(enabledTokens));
        // 4. ensure stablecoinEnabled function returns true, since both tokens were added
        assertEq(paymentModule.stablecoinEnabled(membershipInstance, fakeUSDCImpl), true);
        assertEq(paymentModule.stablecoinEnabled(membershipInstance, fakeDAIImpl), true);
        // 5. ensure stablecoinEnabled function reverts, since junk address was not added
        vm.expectRevert("STABLECOIN_NOT_SUPPORTED");
        paymentModule.stablecoinEnabled(membershipInstance, address(789));
        vm.stopPrank();
    }

    function test_enabledTokensValue() public {
        startHoax(owner);
        // 1. add fakeUSDCImpl and fakeDAIImpl to payment module
        paymentModule.append(fakeUSDCImpl);
        paymentModule.append(fakeDAIImpl);
        // 2. create address array of tokens we want enabled
        address[] memory enabledTokens = new address[](2);
        enabledTokens[0] = fakeUSDCImpl;
        enabledTokens[1] = fakeDAIImpl;
        // 3. assert enabledTokens address array returns as we expect
        // since we have two enabled tokens matching keys 1 and 2 we expect a bytes32 value of 0000...0110
        // 0000...0110 = 6
        assertEq(paymentModule.enabledTokensValue(enabledTokens), bytes32(uint256(6)));
        vm.stopPrank();
    }

    function test_append_mint(uint256 price) public {
        // 2 decimals of precision, so price must be less than BASE_BALANCE with that many decimals
        // since that is what the wallet has been given. Else, it will throw insufficient balance error
        vm.assume(price < BASE_BALANCE * 10 ** 2);
        startHoax(owner);
        uint256 preMintDAIBalance = FakeERC20(fakeDAIImpl).balanceOf(owner);
        uint256 preMintUSDCBalance = FakeERC20(fakeUSDCImpl).balanceOf(owner);
        paymentModule.append(fakeUSDCImpl);
        paymentModule.append(fakeDAIImpl);
        address[] memory enabledTokens = new address[](2);
        enabledTokens[0] = fakeUSDCImpl;
        enabledTokens[1] = fakeDAIImpl;
        paymentModule.setup(membershipInstance, price, paymentModule.enabledTokensValue(enabledTokens));
        // test mint with DAI
        paymentModule.mint{value: fee}(membershipInstance, fakeDAIImpl);
        uint256 mintAmountInDAI = paymentModule.getMintPrice(fakeDAIImpl, price);
        // ensure token was minted
        assertEq(membershipContract.ownerOf(1), owner);
        // ensure DAI is spent
        assertEq(FakeERC20(fakeDAIImpl).balanceOf(owner), preMintDAIBalance - mintAmountInDAI);
        // ensure DAI is received
        assertEq(FakeERC20(fakeDAIImpl).balanceOf(paymentReciever), mintAmountInDAI);
        // test mint with USDC
        paymentModule.mint{value: fee}(membershipInstance, fakeUSDCImpl);
        uint256 mintAmountInUSDC = paymentModule.getMintPrice(fakeUSDCImpl, price);
        // ensure token was minted
        assertEq(membershipContract.ownerOf(2), owner);
        // ensure DAI is spent
        assertEq(FakeERC20(fakeUSDCImpl).balanceOf(owner), preMintUSDCBalance - mintAmountInUSDC);
        // ensure DAI is received
        assertEq(FakeERC20(fakeUSDCImpl).balanceOf(paymentReciever), mintAmountInUSDC);
        vm.stopPrank();
    }

    function test_mint_revertIfNoFee(uint256 price) public {
        // 2 decimals of precision, so price must be less than BASE_BALANCE with that many decimals
        // since that is what the wallet has been given. Else, it will throw insufficient balance error
        vm.assume(price < BASE_BALANCE * 10 ** 2);
        startHoax(owner);
        paymentModule.append(fakeUSDCImpl);
        paymentModule.append(fakeDAIImpl);
        address[] memory enabledTokens = new address[](2);
        enabledTokens[0] = fakeUSDCImpl;
        enabledTokens[1] = fakeDAIImpl;
        paymentModule.setup(membershipInstance, price, paymentModule.enabledTokensValue(enabledTokens));
        vm.expectRevert("MISSING_FEE");
        paymentModule.mint(membershipInstance, fakeDAIImpl);
        vm.stopPrank();
    }

    function test_withdrawFee(uint256 price) public {
        // 2 decimals of precision, so price must be less than BASE_BALANCE with that many decimals
        // since that is what the wallet has been given. Else, it will throw insufficient balance error
        vm.assume(price < BASE_BALANCE * 10 ** 2);
        startHoax(owner);
        paymentModule.append(fakeUSDCImpl);
        paymentModule.append(fakeDAIImpl);
        address[] memory enabledTokens = new address[](2);
        enabledTokens[0] = fakeUSDCImpl;
        enabledTokens[1] = fakeDAIImpl;
        paymentModule.setup(membershipInstance, price, paymentModule.enabledTokensValue(enabledTokens));
        paymentModule.mint{value: fee}(membershipInstance, fakeDAIImpl);
        uint256 beforeWithdrawBalance = owner.balance;
        paymentModule.withdrawFee();
        assertEq(owner.balance, beforeWithdrawBalance + fee);
        vm.stopPrank();
    }

    function test_getMintPrice_largerDecimals(uint256 price) public {
        // geting overflows if the price is too high
        vm.assume(price < 10 ** 18);
        startHoax(owner);
        paymentModule.append(fakeUSDCImpl);
        paymentModule.append(fakeDAIImpl);
        address[] memory enabledTokens = new address[](2);
        enabledTokens[0] = fakeUSDCImpl;
        enabledTokens[1] = fakeDAIImpl;
        paymentModule.setup(membershipInstance, price, paymentModule.enabledTokensValue(enabledTokens));
        uint8 moduleDecimals = paymentModule.decimals();
        // test mint with DAI
        uint256 mintPriceInDAI = paymentModule.getMintPrice(fakeDAIImpl, price);
        uint8 daiDecimals = IERC20(fakeDAIImpl).decimals();
        assertEq(mintPriceInDAI, price * 10 ** (daiDecimals - moduleDecimals));
        // test mint with USDC
        uint256 mintPriceInUSDC = paymentModule.getMintPrice(fakeUSDCImpl, price);
        uint8 usdcDecimals = IERC20(fakeUSDCImpl).decimals();
        assertEq(mintPriceInUSDC, price * 10 ** (usdcDecimals - moduleDecimals));
        vm.stopPrank();
    }

    function test_getMintPrice_sameDecimals(uint256 price) public {
        // geting overflows if the price is too high
        vm.assume(price < 10 ** 18);
        startHoax(owner);
        uint8 decimals = paymentModule.decimals();
        address newTokenImpl = address(new FakeERC20(decimals));
        paymentModule.append(newTokenImpl);
        address[] memory enabledTokens = new address[](1);
        enabledTokens[0] = newTokenImpl;
        paymentModule.setup(membershipInstance, price, paymentModule.enabledTokensValue(enabledTokens));

        uint256 mintPrice = paymentModule.getMintPrice(newTokenImpl, price);
        assertEq(mintPrice, price);
        vm.stopPrank();
    }

    function test_getMintPrice_smallerDecimals(uint256 price, uint8 tokenDecimals) public {
        // geting overflows if the price is too high
        vm.assume(price < 10 ** 18);
        uint8 decimals = paymentModule.decimals();
        vm.assume(tokenDecimals < decimals && tokenDecimals > 0);

        startHoax(owner);
        address newTokenImpl = address(new FakeERC20(tokenDecimals));
        paymentModule.append(newTokenImpl);
        address[] memory enabledTokens = new address[](1);
        enabledTokens[0] = newTokenImpl;
        paymentModule.setup(membershipInstance, price, paymentModule.enabledTokensValue(enabledTokens));

        uint256 mintPrice = paymentModule.getMintPrice(newTokenImpl, price);

        assertEq(mintPrice, price / 10 ** (decimals - tokenDecimals));
        vm.stopPrank();
    }

    function test_keyOf_success(uint256 price) public {
        // geting overflows if the price is too high
        vm.assume(price < 10 ** 18);
        startHoax(owner);
        paymentModule.append(fakeUSDCImpl);
        paymentModule.append(fakeDAIImpl);
        address[] memory enabledTokens = new address[](2);
        enabledTokens[0] = fakeUSDCImpl;
        enabledTokens[1] = fakeDAIImpl;
        paymentModule.setup(membershipInstance, price, paymentModule.enabledTokensValue(enabledTokens));

        // match usdc key
        uint8 usdcKey = paymentModule.keyOf(fakeUSDCImpl);
        assertEq(usdcKey, 1);
        // match dai key
        uint8 daiKey = paymentModule.keyOf(fakeDAIImpl);
        assertEq(daiKey, 2);
        vm.stopPrank();
    }

    function test_keyOf_revert(uint256 price) public {
        // geting overflows if the price is too high
        vm.assume(price < 10 ** 18);
        startHoax(owner);
        address newTokenImpl = address(new FakeERC20(2));
        paymentModule.append(fakeUSDCImpl);
        paymentModule.append(fakeDAIImpl);
        address[] memory enabledTokens = new address[](2);
        enabledTokens[0] = fakeUSDCImpl;
        enabledTokens[1] = fakeDAIImpl;
        paymentModule.setup(membershipInstance, price, paymentModule.enabledTokensValue(enabledTokens));

        vm.expectRevert("STABLECOIN_NOT_SUPPORTED");
        uint8 usdcKey = paymentModule.keyOf(newTokenImpl);
        vm.stopPrank();
    }

    function test_updateFee() public {
        startHoax(owner);
        uint256 newFee = 0.0005 ether;
        paymentModule.updateFee(newFee);
        assertEq(paymentModule.fee(), newFee);
        vm.stopPrank();
    }

    function test_updateFee_nonOwner(address nonOwner) public {
        vm.assume(nonOwner != owner);
        startHoax(nonOwner);
        uint256 newFee = 0.0005 ether;
        vm.expectRevert("Ownable: caller is not the owner");
        paymentModule.updateFee(newFee);
        vm.stopPrank();
    }
}