# flashgod

__$22B in crypto across 7 transactions as-a-service__ (as of crypto prices on 6:30 am UTC, 29th Nov 2024).

![absorb](https://github.com/user-attachments/assets/02c2e624-9b74-46a3-b527-c37919a84619)


## Wait wut?!
__flashgod__ is a :feather: weight flash-loan aggregator on all EVM compatible chains (with size), that provides __unbridled__ access to __all__ available assets of __all__ flash-loan providers on 7 different chains, *__in 1 transaction per chain__*, on a clean and easy-to-use interface,

featuring flash-loan providers: _Aave V3, Uniswap V3, Balancer V2_,

on chains: _Ethereum, Arbitrum, Optimism, Polygon, Base, Avalanche, BSC_.


## How?
- Nothing new, but connecting existing dots. Simply a chain of callbacks initiating flashloans from one provider to the next. 

- Things get particularly interesting for Uniswap V3, where flashloans have to be borrowed from multiple pools in a single transaction, in a gas-efficient manner.

- _flashgod_ does so by recursively calling its uniV3 flashloan initiator function from its callback, with clever use of transient storage for persistence of pool data through these calls, to keep things light:<br/><br/>

  <img width="700" alt="Screenshot 2024-11-29 at 12 33 17 PM" src="https://github.com/user-attachments/assets/67c2b952-5d3d-416d-9959-8523e85bd17c">


## Scoop for devs

Cool tricks were possible when transient storage's 1-transaction persistence __yin__, met _flashgod_'s 1-transaction flashloan __yang__:
- __statelessness__: extensive use of transient storage allowed
  - 0 state variables (except the ones inherited which can be removed too)
  - upto 200x cheaper reads and writes across the transaction (max SSTORE = 20k gas against max TSTORE = 100 gas)
  - persistent metadata of providers and flashloaned assets, necessary for the recursive flashloan calls
- __iterable-set__: the key-value nature of transient storage allows for implementing an _Iterable-Set_ data structure using two mappings, 1 to allow adding unique assets in O(1) time, and the other to iterate over these assets through insertion order in O(n) time. This came handy in storing overlapping assets from multiple flashloan providers, uniquely.
- __yul-magic__: using yul wherever sensibly possible to reduce gas drastically, most notably for [decoding bytes array](https://github.com/smitrajput/flashgod/blob/main/src/Tremor.sol#L264) of pool data of all UniV3 pools and storing them in transient storage, in a way that allows for simple and quick access

## Usage
1. Run locally:
    - `git clone git@github.com:smitrajput/flashgod.git && cd flashgod`
    - install foundry (follow [this section](https://book.getfoundry.sh/getting-started/installation#using-foundryup))
    - `forge install`
    - `forge test --via-ir`, should show: <img width="592" alt="Screenshot 2024-11-29 at 6 15 49 PM" src="https://github.com/user-attachments/assets/ebbcdfae-1eef-4a81-9d51-741badb603db">
2. Update [this list](https://github.com/smitrajput/flashgod/blob/main/src/config/Addresses.sol) of addresses with ones you want to flashloan
3. Update corresponding assets and amounts in the test functions of the chains you want to flashloan from. For instance, to flashloan from Ethereum, update the `test_dominoeFlashLoans_ethereum()` function:
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L40) to update aave assets
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L51) to specify amounts for aave
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L65) to update balancer assets
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L75) to specify amounts for balancer
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L82) to update uniV3 assets
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L103) to specify amounts for uniV3
4. Finally, add the logic you want to execute using the aggregated flashloans to [_letsPutASmileOnThatFace()](https://github.com/smitrajput/flashgod/blob/main/src/Tremor.sol#L488)
5. Run the test again for some fireworks.

## Credits
Opening GIF Credits: [A.L.Crego](https://x.com/ALCrego_/status/1860242375118888960)

## Legal
This software is provided "as is", without warranty of any kind. Use at your own risk. The author is not liable for any damages incurred while using this software. 


<!-- flashgod has 0 state variables of its own (except the ones inherited which can be removed too), which drastically reduces total gas costs. The 1-transaction nature of aggregating flashloans aligned elegantly with the killer feature of transient storage being persistent for exactly 1 transaction. This allowed flashgod to share metadata of flashloan providers across various functions, and also to remember all the assets it received, with their amounts. -->

<img width="652" alt="Screenshot 2024-11-29 at 6 27 02 PM" src="https://github.com/user-attachments/assets/f657709f-64d5-42b1-855f-2a648eb7e39a">