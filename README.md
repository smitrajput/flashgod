# flashgod

__$22B in crypto across 7 transactions as-a-service__ (as of crypto prices on 6:30 am UTC, 29th Nov 2024).

![absorb](https://github.com/user-attachments/assets/02c2e624-9b74-46a3-b527-c37919a84619)


## Wait wut?!
__flashgod__ is a light-weight flash-loan aggregator on all EVM compatible chains (with size), that provides __unbridled__ access to __all__ available assets of __all__ flash-loan providers on 7 different chains, *__in 1 transaction per chain__*, on a clean and easy-to-use interface,

featuring flash-loan providers: _Aave V3, Uniswap V3, Balancer V2_,

on chains: _Ethereum, Arbitrum, Optimism, Polygon, Base, Avalanche, BSC_.


## How?
Nothing new, but connecting existing dots. Simply a chain of callbacks initiating flashloans from one provider to the next. 

Things get particularly interesting for Uniswap V3, where flashloans have to be borrowed from multiple pools in a single transaction, in a gas-efficient manner. _flashgod_ does so by recursively calling its uniV3 flashloan initiator function from its callback, with clever use of transient storage to keep things light.

<img width="895" alt="Screenshot 2024-11-29 at 12 33 17 PM" src="https://github.com/user-attachments/assets/67c2b952-5d3d-416d-9959-8523e85bd17c">


## Hot Stuff

Some cool tricks used by flashgod to achieve its goals:
- semi-statelessness: one of the key goals of flashgod was to be as feather-weight as possible, meaning almost 0 use of storage state. The 1-transaction nature of aggregating flashloans aligned elegantly with the killer feature of transient storage being persistent for exactly 1 transaction. This allowed flashgod to share metadata of flashloan providers across various calls, and also to remember all the assets it received, with their amounts.
- hash-set: the key-value nature of transient storage allows for a simple implementation of 2 sets of mappings, 1 to allow adding assets to hash-set in O(1) time, and the other to iterate over all the unique assets to be able to execute strategies using them in O(n) time. Together, looking like an iteratable hash-set.
- yul-magic: using yul wherever sensibly possible to reduce gas, notably for decoding bytes array of pool data of all UniV3 pools and storing them in transient storage, in a way that allows for simple and quick access 

## Usage

## Credits
Opening GIF Credits: [A.L.Crego](https://x.com/ALCrego_/status/1860242375118888960)

## Legal
This software is provided "as is", without warranty of any kind. Use at your own risk. The author is not liable for any damages incurred while using this software. 
