// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "./resources/IWETH.sol";

contract EscrowswapV1 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event TradeOfferCreated(uint256 id, address indexed seller, address indexed tokenOffered,
        address tokenRequested, uint256 indexed amountOffered, uint256 amountRequested);
    event TradeOfferAdjusted(uint256 indexed id, address tokenRequestedUpdated, uint256 amountRequestedUpdated);
    event TradeOfferAccepted(uint256 indexed id, address indexed buyer);
    event TradeOfferCancelled(uint256 indexed id);

    struct TradeOffer {
        address seller;
        address tokenOffered;
        address tokenRequested;
        uint256 amountOffered;
        uint256 amountRequested;
    }

    bool private EMERGENCY_WITHDRAWAL;
    uint256 private id_counter;
    uint256 private BASE_FEE;
    IWETH immutable weth;

    mapping(uint256 => TradeOffer) private tradeOffers;
    mapping(bytes32 => uint256) private tradingPairFees;

    constructor() {
        id_counter = 0;
        BASE_FEE = 2500; // 2500 / 100000 = 2.5%
        EMERGENCY_WITHDRAWAL = false;
        weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    }

    function createTradeOffer(address _tokenOffered, uint256 _amountOffered, address _tokenRequested, uint256 _amountRequested) payable external nonReentrant nonEmergencyCall {
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

        _handleEscrowTransfer(
            msg.sender,
            _amountOffered,
            _tokenOffered,
            address(this)
        );
    }

    // @ ZORA V3
    function _handleEscrowTransfer(address _sender, uint256 _amount, address _token, address _dest) internal {
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

    function _handleFeePayout(address _sender, uint256 _amount, address _tokenReq, address _tokenOff) internal {
        uint256 fee = tradingPairFees[_getTradingPairHash(_tokenReq, _tokenOff)];
        if (fee == 0) {
            fee = BASE_FEE;
        }

        // FEE Payment transaction
        _handleEscrowTransfer(
            msg.sender,
            _amount * fee / 100000,
            _tokenReq,
            owner()
        );
    }

    function _handleOutgoingTransfer(address _dest, uint256 _amount, address _token) internal {
        if (_amount == 0 || _dest == address(0)) {
            return;
        }

        // Handle ETH payment
        if (_token == address(0)) {
            require(address(this).balance >= _amount, "_handleOutgoingTransfer insolvent");

            (bool success, ) = _dest.call{value: _amount}("");
            // If the ETH transfer fails, wrap the ETH and try send it as WETH.
            if (!success) {
                weth.deposit{value: _amount}();
                IERC20(address(weth)).safeTransfer(_dest, _amount);
            }
        } else {
            IERC20(_token).safeTransfer(_dest, _amount);
        }
    }

    function acceptTradeOffer(uint256 _id, address _tokenRequested, uint256 _amountRequested) payable external nonReentrant nonEmergencyCall {
        TradeOffer memory trade = tradeOffers[_id];

        require(trade.tokenRequested == _tokenRequested, "Trade data misaligned");
        require(trade.amountRequested == _amountRequested, "Trade data misaligned");
        require(IERC20(trade.tokenRequested).balanceOf(msg.sender) >= trade.amountRequested,
            "Insufficient balance");

        deleteTradeOffer(_id);
        emit TradeOfferAccepted(_id, msg.sender);

        //Transfer from buyer to seller.
        _handleEscrowTransfer(
            msg.sender,
            trade.amountRequested,
            trade.tokenRequested,
            address(trade.seller)
        );

        //Fee Payment calculation and exec.
        _handleFeePayout(
            msg.sender,
            trade.amountRequested,
            trade.tokenRequested,
            trade.tokenOffered
        );

        //Transfer from the vault to buyer.
        _handleOutgoingTransfer(msg.sender, trade.amountOffered, trade.tokenOffered);
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

        //Transfer from the vault back to the owner.
        _handleOutgoingTransfer(address(trade_seller), trade_amountOffered, trade_tokenOffered);
    }

    function getTradeOffer(uint256 _id) external view returns(TradeOffer memory) {
        return tradeOffers[_id];
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
