// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "./resources/IWETH.sol";
import "forge-std/console.sol";

contract EscrowswapV1 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint16 immutable private GAS_LIMIT;
    uint256 immutable private TOKEN_AMOUNT_LIMIT;
    IWETH immutable private weth;
    address private feePayoutAddress;
    uint256 immutable private baseFeeDenominator;
    uint256 private idCounter;
    uint256 private baseFee;

    bool public isEmergencyWithdrawalActive;

    struct TradeOffer {
        address seller;
        address tokenOffered;
        address tokenRequested;
        uint256 amountOffered;
        uint256 amountRequested;
    }

    /// ------------ STORAGE ------------

    mapping(uint256 => TradeOffer) private tradeOffers;
    mapping(bytes32 => uint16) private tradingPairFees;

    /// ------------ EVENTS ------------

    event TradeOfferCreated(uint256 id, address indexed seller, address indexed tokenOffered,
        address tokenRequested, uint256 indexed amountOffered, uint256 amountRequested);
    event TradeOfferAdjusted(uint256 indexed id, address tokenRequestedUpdated, uint256 amountRequestedUpdated);
    event TradeOfferAccepted(uint256 indexed id, address indexed buyer);
    event TradeOfferCancelled(uint256 indexed id);

    /// ------------ MODIFIERS ------------

    modifier nonEmergencyCall() {
        require(!isEmergencyWithdrawalActive, "Emergency withdrawal is being active.");
        _;
    }

    /// ------------ CONSTRUCTOR ------------

    constructor() {
        idCounter = 0;

        baseFee = 2_000; // 2000 / 100000 = 2.0%
        baseFeeDenominator = 100_000;
        feePayoutAddress = owner();

        weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        GAS_LIMIT = 50_000;
        TOKEN_AMOUNT_LIMIT = 23158e69;
        isEmergencyWithdrawalActive = false;
    }

    /// ------------ MAKER FUNCTIONS ------------

    function createTradeOffer(address _tokenOffered, uint256 _amountOffered, address _tokenRequested, uint256 _amountRequested)
    payable
    external
    nonReentrant
    nonEmergencyCall
    returns (uint256 tradeId)
    {
        require(_amountOffered > 0, "Empty trade.");
        require(_amountRequested > 0, "Empty trade.");
        require(_amountRequested < TOKEN_AMOUNT_LIMIT, "Value cannot be processed due to potential overflow.");

        tradeId = idCounter;
        TradeOffer memory newOffer = TradeOffer({
            seller: msg.sender,
            tokenOffered: _tokenOffered,
            tokenRequested: _tokenRequested,
            amountOffered: _amountOffered,
            amountRequested: _amountRequested
        });

        tradeOffers[idCounter] = newOffer;

        ++idCounter;

        emit TradeOfferCreated(tradeId, newOffer.seller, newOffer.tokenOffered,
            newOffer.tokenRequested, newOffer.amountOffered, newOffer.amountRequested);

        _handleIncomingTransfer(
            msg.sender,
            _amountOffered,
            _tokenOffered,
            address(this)
        );
    }

    function adjustTradeOffer(uint256 _id, address _tokenRequestedUpdated, uint256 _amountRequestedUpdated)
    external
    nonEmergencyCall
    {
        require(_amountRequestedUpdated < TOKEN_AMOUNT_LIMIT, "Value cannot be processed due to potential overflow.");

        TradeOffer storage trade = tradeOffers[_id];
        require(trade.seller == msg.sender, "Unauthorized access to the trade.");
        require(trade.amountOffered > 0, "Empty trade.");

        trade.amountRequested = _amountRequestedUpdated;
        trade.tokenRequested = _tokenRequestedUpdated;

        emit TradeOfferAdjusted(_id, _tokenRequestedUpdated, _amountRequestedUpdated);
    }

    function cancelTradeOffer(uint256 _id) external nonReentrant {
        //saving gas: only necessary vars in the memory
        address trade_seller = tradeOffers[_id].seller;
        uint256 trade_amountOffered = tradeOffers[_id].amountOffered;
        address trade_tokenOffered = tradeOffers[_id].tokenOffered;

        require(trade_amountOffered > 0, "Empty trade.");
        require(trade_seller == msg.sender, "Unauthorized access to the trade.");

        _deleteTradeOffer(_id);
        emit TradeOfferCancelled(_id);

        //Transfer from the vault back to the trade creator.
        _handleOutgoingTransfer(address(trade_seller), trade_amountOffered, trade_tokenOffered, GAS_LIMIT);
    }

    /// ------------ TAKER FUNCTIONS ------------

    function acceptTradeOffer(uint256 _id, address _tokenRequested, uint256 _amountRequested)
    payable
    external
    nonReentrant
    nonEmergencyCall
    {
        TradeOffer memory trade = tradeOffers[_id];

        require(trade.tokenRequested == _tokenRequested, "Trade data misaligned");
        require(trade.amountRequested == _amountRequested, "Trade data misaligned");
        require(trade.amountOffered > 0, "Empty trade.");

        _deleteTradeOffer(_id);
        emit TradeOfferAccepted(_id, msg.sender);

        //Transfer from buyer to seller.
        _handleRelayTransfer(
            msg.sender,
            trade.amountRequested,
            trade.tokenRequested,
            address(trade.seller),
            GAS_LIMIT
        );

        console.log("Handling fee");
        //Fee Payment calculation and exec.
        _handleFeePayout(
            msg.sender,
            trade.amountRequested,
            trade.tokenRequested,
            trade.tokenOffered
        );

        //Transfer from the vault to buyer.
        _handleOutgoingTransfer(msg.sender, trade.amountOffered, trade.tokenOffered, GAS_LIMIT);
    }

    /// ------------ MASTER FUNCTIONS ------------

    function switchEmergencyWithdrawal(bool _switch) external onlyOwner {
        isEmergencyWithdrawalActive = _switch;
    }

    function setTradingPairFee(bytes32 _hash, uint16 _fee) external onlyOwner {
        tradingPairFees[_hash] = _fee;
    }

    function deleteTradingPairFee(bytes32 _hash) external onlyOwner {
        delete tradingPairFees[_hash];
    }

    function setBaseFee(uint256 _fee) external onlyOwner {
        baseFee = _fee;
    }

    function setFeePayoutAddress(address _addr) external onlyOwner {
        feePayoutAddress = _addr;
    }

    /// ------------ VIEW FUNCTIONS ------------

    function getTradingPairFee(bytes32 _hash) public view returns (uint256)  {
        uint256 fee = tradingPairFees[_hash];
        if(fee == 0) return baseFee;
        return fee;
    }

    function getTradeOffer(uint256 _id) external view returns (TradeOffer memory) {
        return tradeOffers[_id];
    }

    /// ------------ HELPER FUNCTIONS ------------

    function _handleFeePayout(address _sender, uint256 _amount, address _tokenReq, address _tokenOff) private {

        // Sometimes decimal number of a token is too low or it's not possible to calculate
        // the fee without rounding it to ZERO.
        // In that case we request 1 unit of the token to be sent as a fee.
        uint256 fee = getTradingPairFee(_getTradingPairHash(_tokenReq, _tokenOff)) * _amount / baseFeeDenominator;
        if (fee == 0) {
            fee = 1;
        }

        console.log("Executing fee transfer");
        // FEE Payment transaction
        _handleRelayTransfer(
            _sender,
            fee,
            _tokenReq,
            feePayoutAddress,
            GAS_LIMIT
        );
    }

    function _handleIncomingTransfer(address _sender, uint256 _amount, address _token, address _dest) private {
        if (_token == address(0)) {
            require(msg.value >= _amount, "_handleIncomingTransfer msg value less than expected amount");
        } else {
            // We must check the balance that was actually transferred to this contract,
            // as some tokens impose a transfer fee and would not actually transfer the
            // full amount to the escrowswap, resulting in potentially locked funds
            IERC20 token = IERC20(_token);
            uint256 beforeBalance = token.balanceOf(_dest);
            token.safeTransferFrom(_sender, _dest, _amount);
            uint256 afterBalance = token.balanceOf(_dest);
            require(beforeBalance + _amount == afterBalance, "_handleIncomingTransfer token transfer call did not transfer expected amount");
        }
    }

    function _handleRelayTransfer(address _sender, uint256 _amount, address _token, address _dest, uint256 _gasLimit) private {
        if (_token == address(0)) {
            require(msg.value >= _amount, "_handleRelayTransfer msg value less than expected amount");
            _handleEthTransfer(_dest, _amount, _gasLimit);
        } else {
            IERC20(_token).safeTransferFrom(_sender, _dest, _amount);
        }
    }

    function _handleOutgoingTransfer(address _dest, uint256 _amount, address _token, uint256 _gasLimit) private {
        // Handle ETH payment
        if (_token == address(0)) {
            require(address(this).balance >= _amount, "_handleOutgoingTransfer insolvent");
            _handleEthTransfer(_dest, _amount, _gasLimit);
        } else {
            IERC20(_token).safeTransfer(_dest, _amount);
        }
    }

    function _handleEthTransfer(address _dest, uint256 _amount, uint256 _gasLimit) private {
        uint256 gas = (_gasLimit > gasleft()) ? gasleft() : _gasLimit;
        (bool success, ) = _dest.call{value: _amount, gas: gas}("");
        // If the ETH transfer fails, wrap the ETH and try send it as WETH.
        if (!success) {
            weth.deposit{value: _amount}();
            IERC20(address(weth)).safeTransfer(_dest, _amount);
        }
    }

    function _deleteTradeOffer(uint256 _id) private {
        delete tradeOffers[_id];
    }

    function _getTradingPairHash(address _token0, address _token1) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(_token0, _token1));
    }
}
