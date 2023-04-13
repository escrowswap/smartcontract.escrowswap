// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";


interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract EscrowswapV1 is Ownable, ReentrancyGuard {

    event TradeOfferCreated(uint256 id, address indexed seller, address indexed tokenOffered,
        address tokenRequested, uint256 indexed amountOffered, uint256 amountRequested);
    event TradeOfferAdjusted(uint256 id, uint256 indexed amountOfferedUpdated, uint256 amountRequestedUpdated); //can be vulnerable when user pays and then this happens
    event TradeOfferAccepted(uint256 id);
    event TradeOfferCancelled(uint256 id);

    TradeOffer[] public tradeOffers;

    // Getting packed by bit-shifting
    struct TradeOffer {
        uint256 id;
        address seller;
        address buyer;
        address tokenOffered;
        address tokenRequested;
        uint256 amountOffered;
        uint256 amountRequested;
        bool usingCollateral; // questionable, might be changed later
    }

    constructor() {
    }

    function createTradeOffer(address _tokenOffered, uint256 _amountOffered, address _tokenRequested, uint256 _amountRequested) external payable nonReentrant {
        IERC20(_tokenOffered).transferFrom(
            msg.sender,
            address(this),
            _amountOffered
        );

        TradeOffer memory newOffer = TradeOffer({
            id: tradeOffers.length,
            seller: msg.sender,
            buyer: address(0),
            tokenOffered: _tokenOffered,
            tokenRequested: _tokenRequested,
            amountOffered: _amountOffered,
            amountRequested: _amountRequested,
            usingCollateral: false
        });

        tradeOffers.push(newOffer);

        emit TradeOfferCreated(newOffer.id, newOffer.seller, newOffer.tokenOffered,
            newOffer.tokenRequested, newOffer.amountOffered, newOffer.amountRequested);
    }

    function acceptTradeOffer(uint256 id) external {
        tradeOffers[id].buyer = msg.sender;
        TradeOffer storage trade = tradeOffers[id];

        IERC20(trade.tokenRequested).transferFrom(
            msg.sender,
            address(trade.seller),
            trade.amountRequested
        );

        IERC20(trade.tokenOffered).transfer(
            msg.sender,
            trade.amountOffered
        );
    }

    function adjustTradeOffer() external  {

    }

    function cancelTradeOffer() external {

    }

    function setFeeLevel(uint8 fee) external onlyOwner {

    }
}
