// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract EscrowswapV1 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event TradeOfferCreated(uint256 id, address indexed seller, address indexed tokenOffered,
        address tokenRequested, uint256 indexed amountOffered, uint256 amountRequested);
    event TradeOfferAdjusted(uint256 indexed id, address tokenRequestedUpdated, uint256 amountRequestedUpdated);
    event TradeOfferAccepted(uint256 indexed id, address indexed buyer);
    event TradeOfferCancelled(uint256 indexed id);

    struct TradeOffer {
        address seller;
        //address buyer;
        address tokenOffered;
        address tokenRequested;
        uint256 amountOffered;
        uint256 amountRequested;
    }

    mapping(bytes32 => uint256) tradingPairFees;

    uint256 private id_counter;
    bool private EMERGENCY_WITHDRAWAL = false;
    uint256 private BASE_FEE = 2500;
    mapping(uint256 => TradeOffer) public tradeOffers;

    constructor() {
        id_counter = 0;
    }

    function createTradeOffer(address _tokenOffered, uint256 _amountOffered, address _tokenRequested, uint256 _amountRequested) external nonReentrant nonEmergencyCall {
        require(IERC20(_tokenOffered).balanceOf(msg.sender) >= _amountOffered, "Insufficient balance of offered tokens.");

        TradeOffer memory newOffer = TradeOffer({
            seller: msg.sender,
            tokenOffered: _tokenOffered,
            tokenRequested: _tokenRequested,
            amountOffered: _amountOffered,
            amountRequested: _amountRequested
        });

        tradeOffers[id_counter] = newOffer;
        ++id_counter;

        emit TradeOfferCreated(id_counter, newOffer.seller, newOffer.tokenOffered,
            newOffer.tokenRequested, newOffer.amountOffered, newOffer.amountRequested);

        IERC20(_tokenOffered).safeTransferFrom(
            msg.sender,
            address(this),
            _amountOffered
        );
    }

    function acceptTradeOffer(uint256 _id) external nonReentrant nonEmergencyCall {
        TradeOffer memory trade = tradeOffers[_id];

        require(IERC20(trade.tokenRequested).balanceOf(msg.sender) >= trade.amountRequested,
            "Insufficient balance of requested tokens.");

        uint256 fee = tradingPairFees[_getTradingPairHash(trade.tokenRequested, trade.tokenOffered)];
        if (fee == 0) {
            fee = BASE_FEE;
        }

        deleteTradeOffer(_id);
        emit TradeOfferAccepted(_id, msg.sender);

        IERC20(trade.tokenRequested).safeTransferFrom(
            msg.sender,
            address(trade.seller),
            trade.amountRequested
        );

        IERC20(trade.tokenOffered).safeTransfer(
            owner(),
            trade.amountOffered * fee / 100000
        );

        IERC20(trade.tokenOffered).safeTransfer(
            msg.sender,
            trade.amountOffered
        );
    }

    function adjustTradeOffer(uint256 _id, address _tokenRequestedUpdated, uint256 _amountRequestedUpdated) external nonEmergencyCall {
        TradeOffer storage trade = tradeOffers[_id];
        require(trade.seller == msg.sender, "Unauthorized access to the trade.");

        trade.amountRequested = _amountRequestedUpdated;
        trade.tokenRequested = _tokenRequestedUpdated;

        emit TradeOfferAdjusted(_id, _tokenRequestedUpdated, _amountRequestedUpdated);
    }

    function cancelTradeOffer(uint256 _id) external nonReentrant {
        //saving gas: only necessary vars in the memory
        address trade_seller = tradeOffers[_id].seller;
        uint256 trade_amountOffered = tradeOffers[_id].amountOffered;
        address trade_tokenOffered = tradeOffers[_id].tokenOffered;

        require(trade_seller == msg.sender, "Unauthorized access to the trade.");

        deleteTradeOffer(_id);
        emit TradeOfferCancelled(_id);

        IERC20(trade_tokenOffered).safeTransfer(
            address(trade_seller),
            trade_amountOffered
        );
    }

    function getTradeOffer(uint256 _id) external view returns(TradeOffer memory) {
        return tradeOffers[_id];
    }

    function setFeeLevel(uint8 fee) external onlyOwner {
    }

    function switchEmergencyWithdrawal() external onlyOwner {
        EMERGENCY_WITHDRAWAL = !EMERGENCY_WITHDRAWAL;
    }

    function deleteTradeOffer(uint256 _id) internal nonEmergencyCall {
        delete tradeOffers[_id];
    }

    function _getTradingPairHash(address token0, address token1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1));
    }

    function getTradingPairFee(bytes32 hash) external view returns (uint256)  {
        return tradingPairFees[hash];
    }

    function setTradingPairFee(bytes32 hash, uint256 fee) external onlyOwner {
        tradingPairFees[hash] = fee;
    }

    function deleteTradingPairFee(bytes32 hash) external onlyOwner {
        delete tradingPairFees[hash];
    }

    function setBaseFee(uint256 _fee) external onlyOwner {
        BASE_FEE = _fee;
    }

    modifier nonEmergencyCall() {
        require(!EMERGENCY_WITHDRAWAL, "Emergency withdrawal is being active.");
        _;
    }
}
