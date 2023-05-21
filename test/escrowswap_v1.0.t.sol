// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/escrowswap_v1.0.sol";
import "../src/resources/IERC20TEST.sol";
import "test/resources/MockTokenERC20.sol";

import {BrokenToken} from "brokentoken/BrokenToken.sol";

contract EscrowswapV1Test is Test, BrokenToken {
    EscrowswapV1 public escrowswap;
    address public sellerGood;
    address public sellerBad;
    address public buyerGood;
    address public buyerBad;
    address public feePayoutAddress;

    uint256 public TOKEN_AMOUNT_LIMIT;

    IERC20TEST public tokenOffered;
    IERC20TEST public tokenRequested;

    mapping(string => bool) public erc20RevertNames;

    struct TradeOffer {
        address seller;
        address tokenOffered;
        address tokenRequested;
        uint256 amountOffered;
        uint256 amountRequested;
    }
    function setUp() public {
        escrowswap = new EscrowswapV1();

        //create aliases for signers
        sellerGood = vm.addr(1);
        sellerBad = vm.addr(2);
        buyerGood = vm.addr(3);
        buyerBad = vm.addr(4);
        feePayoutAddress = vm.addr(5);

        TOKEN_AMOUNT_LIMIT = 23158e69;

        // Deploy mock ERC20 tokens for testing
        tokenOffered = IERC20TEST(address(new MockTokenERC20("My Token1", "MTK1", 18)));
        tokenRequested = IERC20TEST(address(new MockTokenERC20("My Token2", "MTK2", 18)));

        // Mint tokens for the test accounts
        tokenOffered.mint(sellerGood, 1000);
        tokenOffered.mint(sellerBad, 1000);
        tokenRequested.mint(buyerGood, 1000);
        tokenRequested.mint(buyerBad, 1000);

        vm.deal(sellerGood, 100 ether);
        //vm.deal(sellerBad, 100 ether);
        vm.deal(buyerGood, 100 ether);
        vm.deal(sellerBad, 100 ether);

        //Tokens which are supposed to Revert
        erc20RevertNames["MissingReturnToken"] = true; // formally not ERC20
        erc20RevertNames["ReturnsFalseToken"] = true; // formally not ERC20
        erc20RevertNames["TransferFeeToken"] = true; // due to locked funds issue aren't supported
        erc20RevertNames["Uint96ERC20"] = true;

    }

    /// ------------ createTradeOffer ----------------------------------------------------------------------------------
    // (address _tokenOffered, uint256 _amountOffered, address _tokenRequested, uint256 _amountRequested)
    //
    // event TradeOfferCreated(uint256 id, address indexed seller, address indexed tokenOffered,
    // address tokenRequested, uint256 indexed amountOffered, uint256 amountRequested);

    // 1. Check whether the balance of the vault gets updated with BROKEN-ERC20 except REVERT-ERC20
    function testCreateTradeOfferBrokenERC20(uint256 amountToSell, uint256 amountToReceive) useBrokenToken public {
        vm.assume(amountToSell > 0);
        vm.assume(amountToSell < type(uint256).max);
        vm.assume(amountToReceive > 0);
        vm.assume(amountToReceive < TOKEN_AMOUNT_LIMIT);

        string memory erc20CurrentName = brokenERC20_NAME;
        bool isCurrentErc20Revert = erc20RevertNames[erc20CurrentName];
        if (!isCurrentErc20Revert) {
            deal(address(brokenERC20), sellerGood, amountToSell);

            assertEq(brokenERC20.balanceOf(address(escrowswap)), 0, "EscrowSwap is already in possession of the mentioned token.");

            vm.startPrank(sellerGood);
            brokenERC20.approve(address(escrowswap), amountToSell);

            uint256 tradeId = escrowswap.createTradeOffer(address(brokenERC20), amountToSell, address(tokenRequested), amountToReceive);

            assertEq(brokenERC20.balanceOf(address(escrowswap)), amountToSell, "EscrowSwap has not received the right amount of tokens.");
            vm.stopPrank();

            //checking if everything got saved in the storage correctly
            assertEq(escrowswap.getTradeOffer(tradeId).seller, address(sellerGood), "Different seller.");
            assertEq(escrowswap.getTradeOffer(tradeId).tokenOffered, address(brokenERC20), "Different token.");
            assertEq(escrowswap.getTradeOffer(tradeId).tokenRequested, address(tokenRequested), "Different token.");
            assertEq(escrowswap.getTradeOffer(tradeId).amountOffered, amountToSell, "Different amount.");
            assertEq(escrowswap.getTradeOffer(tradeId).amountRequested, amountToReceive, "Different amount.");
        }
    }

    // 1.5 Check whether the function reverts on REVERT-ERC20
    /*function testCreateTradeOfferRevertERC20(uint128 amountToSell, uint128 amountToReceive) useBrokenToken public {
        vm.assume(amountToSell > 0);
        vm.assume(amountToReceive > 0);

        string memory erc20CurrentName = brokenERC20_NAME;
        bool isCurrentErc20Revert = erc20RevertNames[erc20CurrentName];
        if (isCurrentErc20Revert) {
            deal(address(brokenERC20), sellerGood, amountToSell);

            vm.startPrank(sellerGood);
            brokenERC20.approve(address(escrowswap), amountToSell);
            vm.expectRevert();
            uint256 tradeId = escrowswap.createTradeOffer(address(brokenERC20), amountToSell, address(tokenRequested), amountToReceive);
        }
    }*/

    // 2. Check whether the balance of the vault gets updated with ETH
    function testCreateTradeOfferWithEth(uint256 amountEthToSell) public {
        vm.assume(amountEthToSell > 0);
        vm.deal(sellerGood, amountEthToSell);

        vm.prank(sellerGood);

        assertEq(address(escrowswap).balance, 0, "There is some eth in the vault already.");
        escrowswap.createTradeOffer{value: amountEthToSell}(address(0), amountEthToSell, address(tokenRequested), 3);
        assertEq(address(escrowswap).balance, amountEthToSell, "Not enough eth has been received by the vault.");

        vm.stopPrank();
    }

    /// ------------ adjustTradeOffer ----------------------------------------------------------------------------------

    // 1. Check whether the requested token and amount are changed
    function testAdjustTradeOfferBasic(uint256 amountToReceive_changed, address tokenRequested_changed) public {
        vm.assume(amountToReceive_changed < TOKEN_AMOUNT_LIMIT);

        uint256 amount_sell = 2;
        uint256 amount_get = 10;
        uint256 buyer_amount = tokenRequested.balanceOf(address(buyerGood));

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        uint256 tradeId = escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(tokenRequested), amount_get);

        escrowswap.adjustTradeOffer(tradeId, address(tokenRequested_changed), amountToReceive_changed);
        assertEq(escrowswap.getTradeOffer(tradeId).tokenRequested, address(tokenRequested_changed), "No change has been made to token requested.");
        assertEq(escrowswap.getTradeOffer(tradeId).amountRequested, amountToReceive_changed, "No change has been made to the amount of token requested.");
        vm.stopPrank();
    }

    // 2. Expect revert if trade is being adjusted by NOT SELLER
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

    /// ------------ cancelTradeOffer ----------------------------------------------------------------------------------

    // 1. Check whether the requested trade is getting deleted
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

    // 2. Expect revert if trade is being adjusted by NOT SELLER
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

    /// ------------ acceptTradeOffer ----------------------------------------------------------------------------------

    // 1. Check whether the requested trade is getting accepted. Check if ERC20 tokens get transferred to all the parties.
    function testAcceptTradeOfferBasic(uint256 amountToSell, uint256 amountToReceive) useBrokenToken public {
        vm.assume(amountToSell > 0);
        vm.assume(amountToSell < TOKEN_AMOUNT_LIMIT);
        vm.assume(amountToReceive > 0);
        vm.assume(amountToReceive < TOKEN_AMOUNT_LIMIT);

        string memory erc20CurrentName = brokenERC20_NAME;
        bool isCurrentErc20Revert = erc20RevertNames[erc20CurrentName];
        if (!isCurrentErc20Revert) {
            uint256 calculatedFee = _calculateFee(address(brokenERC20), address(tokenOffered), amountToReceive);
            uint256 balance_buyerGood = tokenOffered.balanceOf(address(buyerGood));
            deal(address(brokenERC20), buyerGood, amountToReceive + calculatedFee);
            tokenOffered.mint(sellerGood, amountToSell);

            // set the address to receive the fee, for testing
            escrowswap.setFeePayoutAddress(feePayoutAddress);

            // create an offer
            vm.startPrank(sellerGood);
            tokenOffered.approve(address(escrowswap), amountToSell);
            uint256 tradeId = escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(brokenERC20), amountToReceive);
            vm.stopPrank();

            // accept the offer
            vm.startPrank(buyerGood);
            brokenERC20.approve(address(escrowswap), amountToReceive + calculatedFee);
            escrowswap.acceptTradeOffer(tradeId, address(brokenERC20), amountToReceive);
            vm.stopPrank();

            // check whether tokens got transferred
            assertEq(brokenERC20.balanceOf(address(sellerGood)), amountToReceive, "Seller has not received the right amount of tokens.");
            assertEq(tokenOffered.balanceOf(address(buyerGood)), amountToSell + balance_buyerGood, "Buyer has not received the right amount of tokens.");
            assertEq(brokenERC20.balanceOf(address(feePayoutAddress)), calculatedFee, "Fee has not been received in the right amount of tokens.");
        }
    }

    // 2. Check whether the requested trade is getting accepted. Check if ETH gets transferred to seller.
    function testAcceptTradeOfferWithSendingEth(uint256 amountTokenToSell, uint256 amountEthToReceive) public {
        vm.assume(amountTokenToSell > 0);
        vm.assume(amountTokenToSell < TOKEN_AMOUNT_LIMIT);
        vm.assume(amountEthToReceive > 0);
        vm.assume(amountEthToReceive < TOKEN_AMOUNT_LIMIT);

        uint256 buyerEthPreBalance;
        uint256 sellerEthPreBalance;

        // setting up the initial amounts
        uint256 calculatedFee = _calculateFee(address(0), address(tokenOffered), amountEthToReceive);
        vm.deal(buyerGood, amountEthToReceive + calculatedFee);
        tokenOffered.mint(sellerGood, amountTokenToSell);
        buyerEthPreBalance = address(buyerGood).balance;
        sellerEthPreBalance = address(sellerGood).balance;

        // set the address to receive the fee, for testing
        escrowswap.setFeePayoutAddress(feePayoutAddress);

        // create an offer
        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amountTokenToSell);
        uint256 tradeId = escrowswap.createTradeOffer(address(tokenOffered), amountTokenToSell, address(0), amountEthToReceive);
        vm.stopPrank();

        // accept the offer
        vm.startPrank(buyerGood);
        escrowswap.acceptTradeOffer{value: amountEthToReceive + calculatedFee}(tradeId, address(0), amountEthToReceive);
        vm.stopPrank();

        assertEq(tokenOffered.balanceOf(address(escrowswap)), 0, "Tokens haven't left escrow.");
        assertEq(address(sellerGood).balance, sellerEthPreBalance + amountEthToReceive, "Seller hasn't received enough eth.");
        assertEq(address(buyerGood).balance, buyerEthPreBalance - amountEthToReceive - calculatedFee, "Buyer hasn't sent enough eth.");
        assertEq(tokenOffered.balanceOf(address(buyerGood)), amountTokenToSell, "Buyer hasn't received enough of tokenOffered.");
        assertEq(address(feePayoutAddress).balance, calculatedFee, "Not enough eth for the FeeAcc.");
    }

    // 3. Check whether the requested trade is getting accepted. Check if ETH gets transferred to buyer.
    function testAcceptTradeOfferWithReceivingEth(uint256 amountEthToSell) public {
        vm.assume(amountEthToSell > 0);
        vm.assume(amountEthToSell < TOKEN_AMOUNT_LIMIT);
        vm.deal(sellerGood, amountEthToSell);
        tokenRequested.mint(buyerGood, 3);

        uint256 buyerEthPreBalance = address(buyerGood).balance;
        uint256 sellerEthPreBalance = address(sellerGood).balance;

        // create an offer
        vm.prank(sellerGood);
        uint256 tradeId = escrowswap.createTradeOffer{value: amountEthToSell}(address(0), amountEthToSell, address(tokenRequested), 1);
        assertEq(address(escrowswap).balance, amountEthToSell, "Not enough eth has been received by the vault.");
        vm.stopPrank();

        // accept the offer
        vm.startPrank(buyerGood);
        tokenRequested.approve(address(escrowswap), 2);
        escrowswap.acceptTradeOffer(tradeId, address(tokenRequested), 1);
        vm.stopPrank();

        assertEq(address(escrowswap).balance, 0, "Eth hasn't left escrow.");
        assertEq(address(sellerGood).balance, sellerEthPreBalance - amountEthToSell, "Seller hasn't sent enough eth.");
        assertEq(address(buyerGood).balance, buyerEthPreBalance + amountEthToSell, "Buyer hasn't received enough eth.");
    }

    // Mimicking how fee is calculated in the actual contract
    function _calculateFee(address _tokenReq, address _tokenOff, uint256 _amount) private returns (uint256) {
        uint256 fee = escrowswap.getTradingPairFee(keccak256(abi.encodePacked(_tokenReq, _tokenOff))) * _amount / 100_000;
        if (fee == 0) {
            fee = 1;
        }
        return fee;
    }

    /// ===================== TESTING FEE FUNCTIONALITY ======================================

    /// GAS test
    function testGetTradingPairFee() public  {
        bytes32 hash = keccak256(abi.encodePacked(address(tokenRequested), address(tokenOffered)));
        uint256 result = escrowswap.getTradingPairFee(hash);
        assertEq(result, 2000, "Non-default fee has been received");
    }

    /// GAS test
    function testSetTradingPairFee() public {
        uint16 fee1 = 4500;
        uint16 fee2 = 6500;
        bytes32 hash = keccak256(abi.encodePacked(address(tokenRequested), address(tokenOffered)));
        escrowswap.setTradingPairFee(hash, fee1);
        uint256 result = escrowswap.getTradingPairFee(hash);
        assertEq(result, fee1, "Wrong fee has been received");

        escrowswap.setTradingPairFee(hash, fee2);
        result = escrowswap.getTradingPairFee(hash);
        assertEq(result, fee2, "Wrong fee has been received");
    }

    /// GAS test
    function testDeleteTradingPairFee() public {
        bytes32 hash = keccak256(abi.encodePacked(address(tokenRequested), address(tokenOffered)));
        escrowswap.setBaseFee(1000);
        escrowswap.setTradingPairFee(hash, 4500);
        uint256 result = escrowswap.getTradingPairFee(hash);
        assertEq(result, 4500, "Different fee has been received");

        escrowswap.deleteTradingPairFee(hash);

        result = escrowswap.getTradingPairFee(hash);
        assertEq(result, 1000, "Non-default fee has been received");
    }

    /// GAS test
    function testSetBaseFee() public {
        escrowswap.setBaseFee(4500);
    }
}
