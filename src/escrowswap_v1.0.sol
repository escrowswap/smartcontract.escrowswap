// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "src/resources/IERC20.sol";

contract EscrowswapV1 is Ownable, ReentrancyGuard {

    event TradeOfferCreated(uint256 id, address indexed seller, address indexed tokenOffered,
        address tokenRequested, uint256 indexed amountOffered, uint256 amountRequested);
    event TradeOfferAdjusted(uint256 id, uint256 indexed amountOfferedUpdated, uint256 amountRequestedUpdated); //can be vulnerable when user pays and then this happens
    event TradeOfferAccepted(uint256 id, address indexed buyer);
    event TradeOfferCancelled(uint256 id);

    TradeOffer[] public tradeOffers;

    //Max and min costs to prevent over/under paying mistakes.
    uint256 public MAX_COST = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 public MIN_COST = 1; //Min of 0.1 USDC

    // Getting packed by bit-shifting
    struct TradeOffer {
        uint256 id;
        address seller;
        //address buyer;
        address tokenOffered;
        address tokenRequested;
        uint256 amountOffered;
        uint256 amountRequested;
    }

    constructor() {
    }

    function createTradeOffer(address _tokenOffered, uint256 _amountOffered, address _tokenRequested, uint256 _amountRequested) external nonReentrant {
        require(IERC20(_tokenOffered).balanceOf(msg.sender) >= _amountOffered, "Insufficient balance of offered tokens.");
        require(_amountOffered >= MIN_COST && _amountRequested >= MIN_COST, "Below min cost");
        require(_amountOffered <= MAX_COST && _amountRequested <= MAX_COST, "Above max cost");

        IERC20(_tokenOffered).transferFrom(
            msg.sender,
            address(this),
            _amountOffered
        );

        TradeOffer memory newOffer = TradeOffer({
            id: tradeOffers.length,
            seller: msg.sender,
            //buyer: address(0),
            tokenOffered: _tokenOffered,
            tokenRequested: _tokenRequested,
            amountOffered: _amountOffered,
            amountRequested: _amountRequested
        });

        tradeOffers.push(newOffer);

        emit TradeOfferCreated(newOffer.id, newOffer.seller, newOffer.tokenOffered,
            newOffer.tokenRequested, newOffer.amountOffered, newOffer.amountRequested);
    }

    function acceptTradeOffer(uint256 _id) external {
        TradeOffer storage trade = tradeOffers[_id];

        require(IERC20(_tokenRequested).balanceOf(msg.sender) >= trade.amountRequested,
            "Insufficient balance of requested tokens.");

        IERC20(trade.tokenRequested).transferFrom(
            msg.sender,
            address(trade.seller),
            trade.amountRequested
        );

        IERC20(trade.tokenOffered).transfer(
            msg.sender,
            trade.amountOffered
        );

        emit TradeOfferAccepted(_id, msg.sender);
    }

    function adjustTradeOffer(uint256 _id, uint256 _amountOfferedUpdated, uint256 _amountRequestedUpdated) external {
        TradeOffer storage trade = tradeOffers[_id];
        require(trade.seller == msg.sender, "Unauthorized access to the trade.");

        trade.amountOffered = _amountOfferedUpdated;
        trade.amountRequested = _amountRequestedUpdated;

        emit TradeOfferAdjusted(_id, _amountOfferedUpdated, _amountRequestedUpdated);
    }

    function cancelTradeOffer(uint256 _id) external {
        TradeOffer storage trade = tradeOffers[_id];
        require(trade.seller == msg.sender, "Unauthorized access to the trade.");
        delete tradeOffers[_id];

        emit TradeOfferCancelled(_id);
    }

    function getTradeOffers() external {

    }

    function setFeeLevel(uint8 fee) external onlyOwner {

    }
}
