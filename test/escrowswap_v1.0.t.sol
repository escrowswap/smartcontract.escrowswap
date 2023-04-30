// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/escrowswap_v1.0.sol";
import "../src/resources/IERC20TEST.sol";
import "test/resources/MockTokenERC20.sol";

contract EscrowswapV1Test is Test {
    EscrowswapV1 public escrowswap;
    address public sellerGood;
    address public sellerBad;
    address public buyerGood;
    address public buyerBad;

    IERC20TEST public tokenOffered;
    IERC20TEST public tokenRequested;

    function setUp() public {
        escrowswap = new EscrowswapV1();

        //create alias for signers
        sellerGood = vm.addr(1);
        sellerBad = vm.addr(2);
        buyerGood = vm.addr(3);
        buyerBad = vm.addr(4);

        // Deploy a mock ERC20 token for testing
        tokenOffered = IERC20TEST(address(new MockTokenERC20("My Token1", "MTK1", 18)));
        tokenRequested = IERC20TEST(address(new MockTokenERC20("My Token2", "MTK2", 18)));

        // Mint tokens for the test accounts
        tokenOffered.mint(sellerGood, 1000);
        tokenOffered.mint(sellerBad, 1000);
        tokenRequested.mint(buyerGood, 1000);
        tokenRequested.mint(buyerBad, 1000);
    }

    /**
    * Testing setup
    */
    function testTokenInteraction() public {
        assertEq(tokenOffered.balanceOf(sellerGood), 1000, "Incorrect initial balance");
        assertEq(tokenRequested.balanceOf(sellerGood), 0, "Incorrect initial balance");
    }

    /**
    * Simple case to check if the function is working
    */
    function testCreateTradeOffer() public {
        vm.startPrank(sellerGood);
        assertEq(tokenOffered.balanceOf(address(escrowswap)), 0, "There is already a token.");

        tokenOffered.approve(address(escrowswap), 1);
        escrowswap.createTradeOffer(address(tokenOffered), uint256(1), address(tokenRequested), uint256(2));

        assertEq(tokenOffered.balanceOf(address(escrowswap)), 1, "Issue with token amount.");
        vm.stopPrank();
    }

    function testAcceptTradeOffer() public {
        uint256 amount_sell = 2;
        uint256 amount_get = 5;
        uint256 buyer_amount = tokenRequested.balanceOf(address(buyerGood));

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(tokenRequested), amount_get);
        vm.stopPrank();

        vm.startPrank(buyerGood);
        tokenRequested.approve(address(escrowswap), amount_get+5);
        escrowswap.acceptTradeOffer(0);

        assertEq(tokenOffered.balanceOf(address(escrowswap)), 0, "Issue with token amount.");
        assertEq(tokenRequested.balanceOf(address(sellerGood)), amount_get, "Issue with token amount.");
        assertEq(tokenRequested.balanceOf(address(buyerGood)), buyer_amount - amount_get, "Issue with token amount.");
        assertEq(tokenOffered.balanceOf(address(buyerGood)), amount_sell, "Issue with token amount.");

        vm.stopPrank();
    }

    function testAdjustTradeOffer() public {
        uint256 amount_sell = 2;
        uint256 amount_get = 10;
        uint256 buyer_amount = tokenRequested.balanceOf(address(buyerGood));

        uint256 amount_changed = 5;

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(tokenRequested), amount_get);

        escrowswap.adjustTradeOffer(0, address(tokenOffered), amount_changed);
        assertEq(escrowswap.getTradeOffer(0).tokenRequested, address(tokenOffered), "No change has been made to token requested.");
        assertEq(escrowswap.getTradeOffer(0).amountRequested, amount_changed, "No change has been made to the amount of token requested.");
        vm.stopPrank();
    }

    function testAdjustTradeOfferUnauthorized() public {
        uint256 amount_sell = 2;
        uint256 amount_get = 5;
        uint256 buyer_amount = tokenRequested.balanceOf(address(buyerGood));

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(tokenRequested), amount_get);
        vm.stopPrank();

        //transaction fails because of unauthorized access
        vm.startPrank(sellerBad);
        vm.expectRevert();
        escrowswap.adjustTradeOffer(0, address(tokenOffered), 5);
        vm.stopPrank();
    }

    function testCancelTradeOfferUnauthorized() public {
        uint256 amount_sell = 2;
        uint256 amount_get = 5;
        uint256 buyer_amount = tokenRequested.balanceOf(address(buyerGood));

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(tokenRequested), amount_get);
        vm.stopPrank();

        //transaction fails because of unauthorized access
        vm.startPrank(sellerBad);
        vm.expectRevert();
        escrowswap.cancelTradeOffer(0);
        vm.stopPrank();
    }

    function testCancelTradeOffer() public {
        uint256 amount_sell = 2;
        uint256 amount_get = 5;
        uint256 seller_amount = tokenRequested.balanceOf(address(buyerGood));

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(tokenRequested), amount_get);

        assertEq(tokenOffered.balanceOf(address(escrowswap)), amount_sell, "Contract has not received the token.");
        assertEq(tokenOffered.balanceOf(address(sellerGood)), seller_amount - amount_sell, "Contract hasn't received the tokens FROM the seller.");

        escrowswap.cancelTradeOffer(0);

        assertEq(tokenOffered.balanceOf(address(escrowswap)), 0, "Tokens have not been sent back.");
        assertEq(tokenOffered.balanceOf(address(sellerGood)), seller_amount, "Tokens have not been sent back TO THE RIGHTFUL SELLER.");

        vm.stopPrank();
    }

    //=====================TESTING FEE FUNCTIONALITY======================================

    function testGetTradingPairFee() public  {
        bytes32 hash = keccak256(abi.encodePacked(address(tokenRequested), address(tokenOffered)));
        uint256 result = escrowswap.getTradingPairFee(hash);
        assertEq(result, 0, "Non-default fee has been received");
    }

    function testSetTradingPairFee() public {
        uint256 fee1 = 4500;
        uint256 fee2 = 6500;
        bytes32 hash = keccak256(abi.encodePacked(address(tokenRequested), address(tokenOffered)));
        escrowswap.setTradingPairFee(hash, fee1);
        uint256 result = escrowswap.getTradingPairFee(hash);
        assertEq(result, fee1, "Wrong fee has been received");

        escrowswap.setTradingPairFee(hash, fee2);
        result = escrowswap.getTradingPairFee(hash);
        assertEq(result, fee2, "Wrong fee has been received");
    }

    function testDeleteTradingPairFee() public {
        bytes32 hash = keccak256(abi.encodePacked(address(tokenRequested), address(tokenOffered)));
        escrowswap.setTradingPairFee(hash, 4500);
        uint256 result = escrowswap.getTradingPairFee(hash);
        assertEq(result, 4500, "Different fee has been received");

        escrowswap.deleteTradingPairFee(hash);

        result = escrowswap.getTradingPairFee(hash);
        assertEq(result, 0, "Non-default fee has been received");
    }

    function testSetBaseFee() public {
        escrowswap.setBaseFee(4500);
    }
}
