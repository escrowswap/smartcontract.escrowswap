# Escrowswap V1 ⬛️🐦

##### A secure escrow contract for an OTC trade desk.

---

`OTC trade` - OTC stands for "Over-the-Counter." In the context of financial markets, an OTC trade refers to a transaction that takes place directly between two parties without going through an exchange.

[www.escrowswap.xyz](https://escrowswap.xyz) - web3 platform, which allows users to create and adjust otc trades. All open trades are listed on the website for the users to navigate easily.

## Why is escrowswap useful?
- `On-chain mechanism` escrowswap offers secure experience by managing the transactions on-chain. **Trust the code.**
- `Zero slippage` OTC deals are particularly **useful for large volume transactions**, as they provide higher liquidity. In decentralized exchanges, slippage (the price difference between the expected price and the executed price) may occur, especially for large orders or illiquid tokens.
- `Price stability` Escrowswap offers **fixed pricing** for large orders, which **helps maintain price stability** during the transaction. On decentralized exchanges, placing a large order could result in significant price movement.
- `Wide Asset Selection` Escrowswap allows creating trades for almost **any pair of ERC20 tokens**.
- `Privacy` direct on-chain interaction with other users **doesn't require verification**.

---
## FAQ

#### Super High-level architecture
```

   ,-.                                                          ,-. 
   `-'                                                          `-'
   /|\                                                          /|\
    |                                                            |
   / \                       +-------------+                    / \
  maker                      | escrowswap  |                   taker 
+-------+                    +-------------+                 +-------+
    |                               |                            |
    | createTradeOffer(id1)         |                            |
    |------------------------------>|                            |
    |                               |                            |
    | adjustTradeOffer(id1)         |                            |
    |------------------------------>|                            |
    |                               |                            |
    | cancelTradeOffer(id1)         |                            |
    |------------------------------>|                            |
    |                               |                            |
    | createTradeOffer(id20)        |                            |
    |------------------------------>|                            |
    |                               |                            |
    |                               |     acceptTradeOffer(id20) |
    |                               |<---------------------------|
    |                               |                            |
```

#### For everyone
- if `ETH` transfer fails, we try wrapping it and sending as `WETH`.
- if `EMERGENCY WITHDRAWAL` is active, only calls to `cancelTradeOffer()` are allowed.

#### For trade makers
- send the whole offered amount to the contract's vault when creating a trade.
- **do not pay any fees**
- can adjust the trade
- can cancel the trade and refund

#### For trade takers
- accept the trade, receive the funds from the vault, send funds to the maker
- **pay the calculated fee**

#### For the fee payment
- default fee is initially set to 2% of the `_tokenAmount` in `_tokenRequested`
- default fee can be adjusted to provide the best rates to stay competitive
- default fee is expected to be always `< 5%` to avoid overflow error during execution.
- unique `_traidingPairFee` can be set for a specific `_tokenRequested -> _tokenOffered` pair by escrowswap.
- unique `_traidingPairFee` can be set to either `> _baseFee` or `< _baseFee` to provide unique rates for extreme high or low liquidity pairs.
- if the `_tokenRequested` is low-decimal, escrowswap takes `1` unit of the mentioned token instead of the `_baseFee`.

---
## Limitations
- `_requestedAmount` is capped to `TOKEN_AMOUNT_LIMIT = 23158*10^69;` to avoid overflow when calculating fees.
- Tokens with missing return statements **are not supported**.
- Tokens that do not allow to send the full requested amount and require transfer fee **are not supported**.
- Tokens that do not allow to send the `amount > allowed amount mentioned in their contract` **might revert**. 

---
## Maker (seller) functions
#### `createTradeOffer`
##### `(_tokenOffered, _amountOffered, _tokenRequested, _amountRequested)`
- saves tradeOffer in the contract
- creates an on-chain event
- sends the full `_amountOffered` of `_tokenOffered` that user is willing to sell.
---
#### `adjustTradeOffer`
##### `(_id, _tokenRequestedUpdated, _amountRequestedUpdated)`
- finds the trade by id and checks if the user is authorized to adjust the offer.
- user is allowed to change the requested ERC20 token or/and the requested amount.
---
#### `cancelTradeOffer`
##### `(_id)`
- finds the trade by id and checks if the user is authorized to cancel the offer.
- cancels the offer, deletes it from the storage and refunds the tokens.

---

## Taker (buyer) functions

#### `acceptTradeOffer`
##### `(_id, _tokenRequested, _amountRequested)`
- checks if `_tokenRequested` and `_amountRequested` accepted by the taker actually align with the current state of the trade.
- sends the `_amountRequested` of `_tokenRequested` from taker address to maker address.
- sends calculated `FEE` in `_tokenRequested` to the escrowswap's payout address.
- sends the trade's `_amountOffered` in `_tokenOffered` to the taker.
- deletes the trade from the storage.

---

## Escrowswap's owner functions

#### `swithcEmergencyWithdrawal`
##### `(switch)`
- enables or disables the EMERGENCY WITHDRAWAL
---
#### `setTraidingPairFee`
##### `(_traidingPairhash, _fee)`
- sets a unique fee rate for a certain `_tokenRequested -> _tokenOffered` pair.
---
#### `deletesTraidingPairFee`
##### `(_traidingPairhash)`
- deletes a unique fee rate for a certain `_tokenRequested -> _tokenOffered` pair.
---
#### `setBaseFee`
##### `(_fee)`
- sets a base fee rate for a all the token pairs which don't have unique fee rates.
---
#### `setFeePayoutAddress`
##### `(_addr)`
- sets an `_addr` which will receive the fees on behalf of escrowswap
