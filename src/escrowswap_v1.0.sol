// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "src/resources/IERC20.sol";

contract EscrowswapV1 is Ownable, ReentrancyGuard {

    event TradeOfferCreated(uint256 id, address indexed seller, address indexed tokenOffered,
        address tokenRequested, uint256 indexed amountOffered, uint256 amountRequested);
    event TradeOfferAdjusted(uint256 id, address tokenRequestedUpdated, uint256 amountRequestedUpdated);
    event TradeOfferAccepted(uint256 id, address indexed buyer);
    event TradeOfferCancelled(uint256 id);

    struct TradeOffer {
        address seller;
        //address buyer;
        address tokenOffered;
        address tokenRequested;
        uint256 amountOffered;
        uint256 amountRequested;
    }

    bool EMERGENCY_WITHDRAWAL = false;
    uint256 public MAX_COST = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 public MIN_COST = 0;

    uint256 private id_counter;

    constructor() {
        id_counter = 0;
    }

    mapping(uint256 => TradeOffer) public tradeOffers;

    function createTradeOffer(address _tokenOffered, uint256 _amountOffered, address _tokenRequested, uint256 _amountRequested) external nonReentrant nonEmergencyCall {
        require(IERC20(_tokenOffered).balanceOf(msg.sender) >= _amountOffered, "Insufficient balance of offered tokens.");
        require(_amountOffered >= MIN_COST && _amountRequested >= MIN_COST, "Below min cost");
        require(_amountOffered <= MAX_COST && _amountRequested <= MAX_COST, "Above max cost");

        IERC20(_tokenOffered).transferFrom(
            msg.sender,
            address(this),
            _amountOffered
        );

        TradeOffer memory newOffer = TradeOffer({
            seller: msg.sender,
            tokenOffered: _tokenOffered,
            tokenRequested: _tokenRequested,
            amountOffered: _amountOffered,
            amountRequested: _amountRequested
        });

        tradeOffers[id_counter] = newOffer;

        emit TradeOfferCreated(id_counter, newOffer.seller, newOffer.tokenOffered,
            newOffer.tokenRequested, newOffer.amountOffered, newOffer.amountRequested);

        ++id_counter;
    }

    function acceptTradeOffer(uint256 _id) external nonReentrant nonEmergencyCall {
        TradeOffer storage trade = tradeOffers[_id];

        require(IERC20(trade.tokenRequested).balanceOf(msg.sender) >= trade.amountRequested,
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

        deleteTradeOffer(_id);

        emit TradeOfferAccepted(_id, msg.sender);
    }

    function adjustTradeOffer(uint256 _id, address _tokenRequestedUpdated, uint256 _amountRequestedUpdated) external nonEmergencyCall {
        TradeOffer storage trade = tradeOffers[_id];
        require(trade.seller == msg.sender, "Unauthorized access to the trade.");

        trade.amountRequested = _amountRequestedUpdated;
        trade.tokenRequested = _tokenRequestedUpdated;

        emit TradeOfferAdjusted(_id, _tokenRequestedUpdated, _amountRequestedUpdated);
    }

    function cancelTradeOffer(uint256 _id) external nonReentrant {
        TradeOffer storage trade = tradeOffers[_id];
        require(trade.seller == msg.sender, "Unauthorized access to the trade.");

        IERC20(trade.tokenOffered).transfer(
            address(trade.seller),
            trade.amountOffered
        );

        deleteTradeOffer(_id);

        emit TradeOfferCancelled(_id);
    }

    function deleteTradeOffer(uint256 _id) private nonEmergencyCall {
        delete tradeOffers[_id];
    }

    function getTradeOffer(uint256 _id) external view returns(TradeOffer memory) {
        return tradeOffers[_id];
    }

    function setFeeLevel(uint8 fee) external onlyOwner {
    }

    function switchEmergencyWithdrawal() external onlyOwner {
        EMERGENCY_WITHDRAWAL = !EMERGENCY_WITHDRAWAL;
    }

    modifier nonEmergencyCall() {
        require(!EMERGENCY_WITHDRAWAL, "Emergency withdrawal is being active.");
        _;
    }
}
