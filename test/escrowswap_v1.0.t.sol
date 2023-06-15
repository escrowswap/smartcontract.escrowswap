// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

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

    event TradeOfferCreated(uint256 id, address indexed seller, address indexed tokenOffered,
        address tokenRequested, uint256 indexed amountOffered, uint256 amountRequested);
    event TradeOfferAdjusted(uint256 indexed id, address tokenRequestedUpdated, uint256 amountRequestedUpdated);
    event TradeOfferAccepted(uint256 indexed id, address indexed buyer);
    event TradeOfferCancelled(uint256 indexed id);

    function setUp() public {
        escrowswap = new EscrowswapV1(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

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

    // 1. Check whether the balance of the vault gets updated with BROKEN-ERC20 except REVERT-ERC20
    function test_CreateTradeOffer_BrokenERC20(uint256 amountToSell, uint256 amountToReceive) useBrokenToken public {
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

    // 2. Check whether the balance of the vault gets updated with ETH
    function test_CreateTradeOffer_WithEth(uint256 amountEthToSell) public {
        vm.assume(amountEthToSell > 0);
        vm.deal(sellerGood, amountEthToSell);

        vm.prank(sellerGood);

        assertEq(address(escrowswap).balance, 0, "There is some eth in the vault already.");
        escrowswap.createTradeOffer{value: amountEthToSell}(address(0), amountEthToSell, address(tokenRequested), 3);
        assertEq(address(escrowswap).balance, amountEthToSell, "Not enough eth has been received by the vault.");

        vm.stopPrank();
    }

    // 3.
    // amountToSell == 0 represents an empty (DELETED) trade.
    // creating an empty trade is not allowed.
    function testRevert_CreateTradeOffer_ZeroSold() public {
        uint256 amountToSell;
        uint256 amountToReceive;

        vm.prank(sellerGood);

        // amountToSell == 0 represents an empty (DELETED) trade.
        // creating an empty trade is not allowed.
        amountToSell = 0;
        amountToReceive = 1;
        tokenOffered.approve(address(escrowswap), amountToSell);
        vm.expectRevert();
        escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);

        vm.stopPrank();
    }

    // 4.
    // amountToReceive == 0 represents an empty (DELETED) trade.
    // creating an empty trade is not allowed.
    function testRevert_CreateTradeOffer_ZeroRequested() public {
        uint256 amountToSell;
        uint256 amountToReceive;

        vm.prank(sellerGood);

        amountToSell = 1;
        amountToReceive = 0;
        tokenOffered.approve(address(escrowswap), amountToSell);
        vm.expectRevert();
        escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);

        vm.stopPrank();
    }

    // 5.
    // there is a set limit for the requested token amount due to possible overflow when calculating the fee.
    function testRevert_CreateTradeOffer_OverTheLimitRequested() public {
        uint256 amountToSell;
        uint256 amountToReceive;

        vm.prank(sellerGood);

        amountToSell = 1;
        amountToReceive = TOKEN_AMOUNT_LIMIT + 1;
        tokenOffered.approve(address(escrowswap), amountToSell);
        vm.expectRevert();
        escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);

        vm.stopPrank();
    }

    // 6. Emitting the right event with the right vars.
    function testEmit_CreateTradeOffer() public {
        uint256 amountToSell = 1;
        uint256 amountToReceive = 3;

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amountToSell);

        vm.expectEmit();
        emit TradeOfferCreated(0, sellerGood, address(tokenOffered), address(tokenRequested), amountToSell, amountToReceive);
        escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);

        vm.stopPrank();
    }

    /// ------------ adjustTradeOffer ----------------------------------------------------------------------------------

    // 1. Check whether the requested token and amount are changed
    function test_AdjustTradeOffer_Basic(uint256 amountToReceive_changed, address tokenRequested_changed) public {
        vm.assume(amountToReceive_changed < TOKEN_AMOUNT_LIMIT);

        uint256 amount_sell = 2;
        uint256 amount_get = 10;
        uint256 buyer_amount = tokenRequested.balanceOf(address(buyerGood));
        uint256 tradeId;

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        tradeId = escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(tokenRequested), amount_get);

        escrowswap.adjustTradeOffer(tradeId, address(tokenRequested_changed), amountToReceive_changed);
        assertEq(escrowswap.getTradeOffer(tradeId).tokenRequested, address(tokenRequested_changed), "No change has been made to token requested.");
        assertEq(escrowswap.getTradeOffer(tradeId).amountRequested, amountToReceive_changed, "No change has been made to the amount of token requested.");
        vm.stopPrank();
    }

    // 2. Expect revert if trade is being adjusted by NOT SELLER
    function testRevert_AdjustTradeOffer_Unauthorized() public {
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

    // 3.
    // there is a set limit for the requested token amount due to possible overflow when calculating the fee.
    function testRevert_AdjustTradeOffer_OverTheLimitRequested() public {
        uint256 amountToSell = 1;
        uint256 amountToReceive = 1;
        uint256 tradeId;

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amountToSell);
        tradeId = escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);

        vm.expectRevert();
        escrowswap.adjustTradeOffer(tradeId, address(tokenOffered), amountToReceive + TOKEN_AMOUNT_LIMIT);

        vm.stopPrank();
    }

    // 4.
    // amountToSell == 0 represents an empty (DELETED) trade.
    // adjusting an empty trade (cancelled or closed) is not allowed.
    function testRevert_AdjustTradeOffer_ZeroSold() public {
        uint256 amountToSell = 1;
        uint256 amountToReceive = 1;
        uint256 tradeId;

        vm.startPrank(sellerGood);

        // amountToSell == 0 represents an empty (DELETED) trade.
        // adjusting a cancelled or closed trade is not allowed
        tokenOffered.approve(address(escrowswap), amountToSell);
        tradeId = escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);
        escrowswap.cancelTradeOffer(tradeId);

        vm.expectRevert();
        escrowswap.adjustTradeOffer(tradeId, address(tokenOffered), amountToSell);

        vm.stopPrank();
    }

    // 5. Emitting the right event with the right vars.
    function testEmit_AdjustTradeOffer() public {
        uint256 amountToSell = 1;
        uint256 amountToReceive = 3;

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amountToSell);
        uint256 tradeId = escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);

        vm.expectEmit();
        emit TradeOfferAdjusted(tradeId, address(tokenOffered), amountToSell);
        escrowswap.adjustTradeOffer(tradeId, address(tokenOffered), amountToSell);

        vm.stopPrank();
    }

    /// ------------ cancelTradeOffer ----------------------------------------------------------------------------------

    // 1. Check whether the requested trade is getting deleted
    function test_CancelTradeOffer() public {
        uint256 amount_sell = 2;
        uint256 amount_get = 5;
        uint256 seller_amount = tokenRequested.balanceOf(address(buyerGood));
        uint256 tradeId;

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        tradeId = escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(tokenRequested), amount_get);

        assertEq(tokenOffered.balanceOf(address(escrowswap)), amount_sell, "Contract has not received the token.");
        assertEq(tokenOffered.balanceOf(address(sellerGood)), seller_amount - amount_sell, "Contract hasn't received the tokens FROM the seller.");

        escrowswap.cancelTradeOffer(tradeId);

        assertEq(escrowswap.getTradeOffer(tradeId).amountOffered, 0, "Trade has not been deleted");
        assertEq(tokenOffered.balanceOf(address(escrowswap)), 0, "Tokens have not been sent back.");
        assertEq(tokenOffered.balanceOf(address(sellerGood)), seller_amount, "Tokens have not been refunded to the trade owner.");

        vm.stopPrank();
    }

    // 2. Expect revert if trade is being adjusted by NOT SELLER
    function testRevert_CancelTradeOffer_Unauthorized() public {
        uint256 amount_sell = 2;
        uint256 amount_get = 5;
        uint256 buyer_amount = tokenRequested.balanceOf(address(buyerGood));
        uint256 tradeId;

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        tradeId = escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(tokenRequested), amount_get);
        vm.stopPrank();

        //transaction fails because of unauthorized access
        vm.startPrank(sellerBad);
        vm.expectRevert();
        escrowswap.cancelTradeOffer(tradeId);
        vm.stopPrank();
    }

    // 3. Emitting the right event with the right vars.
    function testEmit_CancelTradeOffer() public {
        uint256 amountToSell = 1;
        uint256 amountToReceive = 3;

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amountToSell);
        uint256 tradeId = escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);

        vm.expectEmit();
        emit TradeOfferCancelled(tradeId);
        escrowswap.cancelTradeOffer(tradeId);

        vm.stopPrank();
    }

    /// ------------ acceptTradeOffer ----------------------------------------------------------------------------------

    // 1. Check whether the requested trade is getting accepted. Check if ERC20 tokens get transferred to all the parties.
    // additionally: check whether transaction gets deleted after accepting
    function test_AcceptTradeOffer_Basic(uint256 amountToSell, uint256 amountToReceive) useBrokenToken public {
        vm.assume(amountToSell > 0);
        vm.assume(amountToSell < TOKEN_AMOUNT_LIMIT);
        vm.assume(amountToReceive > 0);
        vm.assume(amountToReceive < TOKEN_AMOUNT_LIMIT);

        string memory erc20CurrentName = brokenERC20_NAME;
        bool isCurrentErc20Revert = erc20RevertNames[erc20CurrentName];
        if (!isCurrentErc20Revert) {
            uint256 tradeId;
            uint256 calculatedFee = _calculateFee(address(brokenERC20), address(tokenOffered), amountToReceive);
            uint256 balance_buyerGood = tokenOffered.balanceOf(address(buyerGood));

            deal(address(brokenERC20), buyerGood, amountToReceive + calculatedFee);
            tokenOffered.mint(sellerGood, amountToSell);

            // set the address to receive the fee, for testing
            escrowswap.setFeePayoutAddress(feePayoutAddress);

            // create an offer
            vm.startPrank(sellerGood);
            tokenOffered.approve(address(escrowswap), amountToSell);
            tradeId = escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(brokenERC20), amountToReceive);
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
            // check whether the trade got deleted
            assertEq(escrowswap.getTradeOffer(tradeId).amountOffered, 0, "Trade has not been deleted.");
        }
    }

    // 2. Check whether the requested trade is getting accepted. Check if ETH gets transferred to seller.
    function test_AcceptTradeOffer_WithSendingEth(uint256 amountTokenToSell, uint256 amountEthToReceive) public {
        vm.assume(amountTokenToSell > 0);
        vm.assume(amountTokenToSell < TOKEN_AMOUNT_LIMIT);
        vm.assume(amountEthToReceive > 0);
        vm.assume(amountEthToReceive < TOKEN_AMOUNT_LIMIT);

        uint256 buyerEthPreBalance;
        uint256 sellerEthPreBalance;
        uint256 tradeId;
        uint256 calculatedFee;

        // setting up the initial amounts
        calculatedFee = _calculateFee(address(0), address(tokenOffered), amountEthToReceive);
        vm.deal(buyerGood, amountEthToReceive + calculatedFee);
        tokenOffered.mint(sellerGood, amountTokenToSell);
        buyerEthPreBalance = address(buyerGood).balance;
        sellerEthPreBalance = address(sellerGood).balance;

        // set the address to receive the fee, for testing
        escrowswap.setFeePayoutAddress(feePayoutAddress);

        // create an offer
        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amountTokenToSell);
        tradeId = escrowswap.createTradeOffer(address(tokenOffered), amountTokenToSell, address(0), amountEthToReceive);
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
    function test_AcceptTradeOffer_WithReceivingEth(uint256 amountEthToSell) public {
        vm.assume(amountEthToSell > 0);
        vm.assume(amountEthToSell < TOKEN_AMOUNT_LIMIT);
        vm.deal(sellerGood, amountEthToSell);
        tokenRequested.mint(buyerGood, 3);

        uint256 buyerEthPreBalance = address(buyerGood).balance;
        uint256 sellerEthPreBalance = address(sellerGood).balance;
        uint256 tradeId;

        // create an offer
        vm.prank(sellerGood);
        tradeId = escrowswap.createTradeOffer{value: amountEthToSell}(address(0), amountEthToSell, address(tokenRequested), 1);
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

    // 4.
    // amountToSell == 0 represents an empty (DELETED) trade.
    // accepting an empty trade (cancelled or closed) is not allowed.
    function testRevert_AcceptTradeOffer_ZeroSold() public {
        uint256 amountToSell = 1;
        uint256 amountToReceive = 1;
        uint256 tradeId;

        vm.startPrank(sellerGood);

        // amountToSell == 0 represents an empty (DELETED) trade.
        // accepting a cancelled or closed trade is not allowed
        tokenOffered.approve(address(escrowswap), amountToSell);
        tradeId = escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);
        escrowswap.cancelTradeOffer(tradeId);

        vm.expectRevert();
        // aligning the trade data by sending default values as parameters (since the trade has been deleted)
        escrowswap.acceptTradeOffer(tradeId, address(0), 0);

        vm.stopPrank();
    }

    // 5. Emitting the right event with the right vars.
    function testEmit_AcceptTradeOffer() public {
        uint256 amountToSell = 1;
        uint256 amountToReceive = 3;

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amountToSell);
        uint256 tradeId = escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);
        vm.stopPrank();

        vm.startPrank(buyerGood);
        tokenRequested.approve(address(escrowswap), 4);
        vm.expectEmit();
        emit TradeOfferAccepted(tradeId, buyerGood);
        escrowswap.acceptTradeOffer(tradeId, address(tokenRequested), amountToReceive);

        vm.stopPrank();
    }

    // Mimicking how fee is calculated in the actual contract
    function _calculateFee(address _tokenReq, address _tokenOff, uint256 _amount) private returns (uint256) {
        uint256 fee = escrowswap.getTradingPairFee(keccak256(abi.encodePacked(_tokenReq, _tokenOff))) * _amount / 100_000;
        if (fee == 0) {
            fee = 1;
        }
        return fee;
    }

    /// ------------ switchEmergencyWithdrawal--------------------------------------------------------------------------

    function test_SwitchEmergencyWithdrawal_Owner() public {
        assertEq(escrowswap.isEmergencyWithdrawalActive(), false);

        escrowswap.switchEmergencyWithdrawal(true);
        assertEq(escrowswap.isEmergencyWithdrawalActive(), true);

        escrowswap.switchEmergencyWithdrawal(false);
        assertEq(escrowswap.isEmergencyWithdrawalActive(), false);
    }

    function testRevert_SwitchEmergencyWithdrawal_NonOwner(address randomUser) public {
        vm.startPrank(randomUser);
        vm.expectRevert();
        escrowswap.switchEmergencyWithdrawal(false);
        vm.stopPrank();
    }

    function testRevert_EmergencyWithdrawal() public {
        vm.startPrank(sellerGood);
        tokenOffered.mint(sellerGood, 4);
        tokenOffered.approve(address(escrowswap), 3);
        uint256 mockTradeId = escrowswap.createTradeOffer(address(tokenOffered), 3, address(tokenRequested), 2);
        vm.stopPrank();

        // owner pauses the contract
        escrowswap.switchEmergencyWithdrawal(true);
        bool isEmergency = escrowswap.isEmergencyWithdrawalActive();

        if (isEmergency) {

            vm.startPrank(buyerGood);
            // accepting trades during emergency is NOT ALLOWED
            tokenRequested.approve(address(escrowswap), 3);
            vm.expectRevert();
            escrowswap.acceptTradeOffer(mockTradeId, address(tokenRequested), 2);
            vm.stopPrank();

            vm.startPrank(sellerGood);
            // creating trades during emergency is NOT ALLOWED
            tokenOffered.mint(sellerGood, 4);
            tokenOffered.approve(address(escrowswap), 3);
            vm.expectRevert();
            escrowswap.createTradeOffer(address(tokenOffered), 3, address(tokenRequested), 2);

            // adjusting trades is NOT ALLOWED
            vm.expectRevert();
            escrowswap.adjustTradeOffer(mockTradeId, address(tokenRequested), 2);

            // cancelling trades is ALLOWED
            escrowswap.cancelTradeOffer(mockTradeId);
            assertEq(escrowswap.getTradeOffer(mockTradeId).amountRequested, 0, "Tokens haven't left escrow");

            vm.stopPrank();
        }
    }

    /// ------------ fee-related testing -------------------------------------------------------------------------------

    function test_SetBaseFee_Owner(uint16 _setFee) public {
        vm.assume(_setFee <= 5000);
        // must return default fee
        bytes32 hash = keccak256(abi.encodePacked(address(tokenRequested), address(tokenOffered)));
        uint256 resultFee;

        escrowswap.setBaseFee(_setFee);
        resultFee = escrowswap.getTradingPairFee(hash);
        assertEq(resultFee, _setFee, "Fee has been set wrong");
    }

    function test_GetTradingPairFee() public  {
        bytes32 hash = keccak256(abi.encodePacked(address(tokenRequested), address(tokenOffered)));
        uint256 result = escrowswap.getTradingPairFee(hash);
        assertEq(result, 2000, "Non-default fee has been received");
    }

    function test_SetTradingPairFee() public {
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

    function test_DeleteTradingPairFee() public {
        bytes32 hash = keccak256(abi.encodePacked(address(tokenRequested), address(tokenOffered)));
        escrowswap.setBaseFee(1000);
        escrowswap.setTradingPairFee(hash, 4500);
        uint256 result = escrowswap.getTradingPairFee(hash);
        assertEq(result, 4500, "Different fee has been received");

        escrowswap.deleteTradingPairFee(hash);

        result = escrowswap.getTradingPairFee(hash);
        assertEq(result, 1000, "Non-default fee has been received");
    }

    function testRevert_SetBaseFee_Unauthorized() public {
        vm.startPrank(sellerGood);
        vm.expectRevert();
        escrowswap.setBaseFee(5000);
        vm.stopPrank();
    }
}
