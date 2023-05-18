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

        // Deploy a mock ERC20 token for testing
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
    }

    function testTokenInteraction() public {
        assertEq(tokenOffered.balanceOf(sellerGood), 1000, "Incorrect initial balance");
        assertEq(tokenRequested.balanceOf(sellerGood), 0, "Incorrect initial balance");
    }

    /// ------------ createTradeOffer ----------------------------------------------------------------------------------
    // (address _tokenOffered, uint256 _amountOffered, address _tokenRequested, uint256 _amountRequested)
    //
    // event TradeOfferCreated(uint256 id, address indexed seller, address indexed tokenOffered,
    // address tokenRequested, uint256 indexed amountOffered, uint256 amountRequested);

    // 1. Check whether the balance of the vault gets updated with ERC20
    function testCreateTradeOfferBasic(uint128 amountToSell, uint128 amountToReceive) public {
        uint256 buyerSellingBalance = tokenRequested.balanceOf(address(buyerGood));
        tokenOffered.mint(sellerGood, amountToSell);
        vm.assume(amountToSell > 0);
        vm.assume(amountToReceive > 0);

        vm.startPrank(sellerGood);
        assertEq(tokenOffered.balanceOf(address(escrowswap)), 0, "EscrowSwap is already in possession of the mentioned token.");

        tokenOffered.approve(address(escrowswap), amountToSell);
        escrowswap.createTradeOffer(address(tokenOffered), amountToSell, address(tokenRequested), amountToReceive);

        assertEq(tokenOffered.balanceOf(address(escrowswap)), amountToSell, "EscrowSwap has not received the right amount of tokens.");
        vm.stopPrank();
    }

    // 2. Check whether the balance of the vault gets updated with ETH
    function testCreateTradeOfferWithEth() public {
        assertEq(address(escrowswap).balance, 0, "There is already some eth.");

        escrowswap.createTradeOffer{value: 1010000000000000000 wei}(address(0), uint256(1010000000000000000), address(tokenRequested), uint256(2));

        assertEq(address(escrowswap).balance, 1010000000000000000, "Issue with amount of received eth.");
    }

    // 3. Check whether the storage gets filled with the right data.
    function testCreateTradeOfferSolventStorage() public {
        uint128 amountToSellMock = 99;
        uint128 amountToReceiveMock = 100;

        testCreateTradeOfferBasic(amountToSellMock, amountToReceiveMock);

        assertEq(escrowswap.getTradeOffer(0).seller, address(sellerGood), "Different seller.");
        assertEq(escrowswap.getTradeOffer(0).tokenOffered, address(tokenOffered), "Different token.");
        assertEq(escrowswap.getTradeOffer(0).tokenRequested, address(tokenRequested), "Different token.");
        assertEq(escrowswap.getTradeOffer(0).amountOffered, amountToSellMock, "Different amount.");
        assertEq(escrowswap.getTradeOffer(0).amountRequested, amountToReceiveMock, "Different amount.");
    }

    // 4. Expect revert if offered balance is 0 (meaning it was not set or the trade was deleted)
    // TRIED FUZZ TESTING
    /*
    function testCreateTradeOfferSolventStorage(uint8 x) public {
        vm.startPrank(sellerGood);
        for (uint i = 0; i < x; i++) {
            tokenOffered.approve(address(escrowswap), 1);
            escrowswap.createTradeOffer(address(tokenOffered), uint256(1), address(tokenRequested), uint256(2));
            tokenOffered.mint(sellerGood, 1);
        }
        vm.stopPrank();
        vm.expectRevert();
        escrowswap.cancelTradeOffer(x);
    } */

    /// ------------ adjustTradeOffer ----------------------------------------------------------------------------------

    // 1. Check whether the requested token and amount are changed
    function testAdjustTradeOfferBasic() public {
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

    // 1. Check whether the requested trade is getting accepted. Check if ERC20 tokens get transferred.
    function testAcceptTradeOfferBasic() public {
        uint256 amount_sell = 200;
        uint256 amount_get = 500;
        uint256 buyer_amount = tokenRequested.balanceOf(address(buyerGood));

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(tokenRequested), amount_get);
        vm.stopPrank();

        vm.startPrank(buyerGood);
        tokenRequested.approve(address(escrowswap), amount_get+500);
        assertEq(tokenRequested.balanceOf(address(sellerGood)), 0, "Issue with token amount seller.");
        escrowswap.acceptTradeOffer(0, address(tokenRequested), amount_get);


        assertEq(tokenOffered.balanceOf(address(escrowswap)), 0, "Issue with token amount escrow.");
        assertEq(tokenRequested.balanceOf(address(sellerGood)), amount_get, "Issue with token amount seller.");
        assertLe(tokenRequested.balanceOf(address(buyerGood)), buyer_amount - amount_get, "Issue with token amount buyer requested.");
        assertEq(tokenOffered.balanceOf(address(buyerGood)), amount_sell, "Issue with token amount buyer offered.");

        vm.stopPrank();
    }

    // 2. Check whether the requested trade is getting accepted. Check if ETH gets transferred.
    function testAcceptTradeOfferWithEth() public {
        uint256 amount_sell = 2;
        uint256 amount_get = 5;
        uint256 buyer_amount = address(buyerGood).balance;
        uint256 seller_amount = address(sellerGood).balance;

        vm.startPrank(sellerGood);
        tokenOffered.approve(address(escrowswap), amount_sell);
        escrowswap.createTradeOffer(address(tokenOffered), amount_sell, address(0), 1010000000000000000);
        vm.stopPrank();

        escrowswap.setFeePayoutAddress(address(sellerBad));

        vm.startPrank(buyerGood);
        escrowswap.acceptTradeOffer{value: 1110000000000000000 wei}(0, address(0), 1010000000000000000);
        vm.stopPrank();

        assertEq(tokenOffered.balanceOf(address(escrowswap)), 0, "Issue with token amount escrow.");
        assertEq(address(sellerGood).balance, seller_amount + 1010000000000000000, "Issue with token amount seller.");
        assertLe(address(buyerGood).balance, buyer_amount - 1010000000000000000, "Issue with token amount buyer requested.");
        assertEq(tokenOffered.balanceOf(address(buyerGood)), amount_sell, "Issue with token amount buyer offered.");
        assertGt(address(sellerBad).balance, 0, "Issue with eth amount escrow.");

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
