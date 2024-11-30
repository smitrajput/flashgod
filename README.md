# flashgod

__$22B in crypto across 7 transactions as-a-service__ (as of crypto prices on 6:30 am UTC, 29th Nov 2024).

![absorb](https://github.com/user-attachments/assets/02c2e624-9b74-46a3-b527-c37919a84619)

## Wait wut?!
__flashgod__ is a :feather: weight flash-loan aggregator on all EVM compatible chains (with size), that provides __unbridled__ access to __all__ available assets of __all__ flash-loan providers on 7 different chains, *__in 1 transaction per chain__*, on a clean and easy-to-use interface,

featuring flash-loan providers: _Aave V3, Uniswap V3, Balancer V2_,

on chains: _Ethereum, Arbitrum, Optimism, Polygon, Base, Avalanche, BSC_.

## Table of Contents

1. [The Power in thy Hands](#the-power-in-thy-hands)
2. [How?](#how)
3. [Purpose](#purpose)
4. [Scoop for Devs](#scoop-for-devs)
5. [Project Structure](#project-structure)
6. [Usage](#usage)
7. [Future Work / Improvements](#future-work--improvements)
8. [Credits](#credits)
9. [Legal](#legal)

## The Power in thy Hands 
amounts fetched for all major assets.<br/>
1 row => 1 txn.<br/>
(as of 29th Nov 2024)

<img width="652" alt="Screenshot 2024-11-29 at 6 27 02 PM" src="https://github.com/user-attachments/assets/f657709f-64d5-42b1-855f-2a648eb7e39a">


## How?
- Nothing new, but connecting existing dots. Simply a chain of callbacks initiating flashloans from one provider to the next. 

- Things get particularly interesting for Uniswap V3, where flashloans have to be borrowed from multiple pools in a single transaction, in a gas-efficient manner.

- _flashgod_ does so by recursively calling its uniV3 flashloan initiator function from its callback, with clever use of transient storage for persistence of pool data through these calls, to keep things light:<br/><br/>

  <img width="700" alt="Screenshot 2024-11-29 at 12 33 17 PM" src="https://github.com/user-attachments/assets/67c2b952-5d3d-416d-9959-8523e85bd17c">


## Purpose
Provide a simpler, light-weight, easy-to-use interface to access much larger flashloans, for
- __market-makers__: to perform arbitrages, liquidations, loan-refinancing, etc.
- __developers__: to test their protocols with real size of attacks that can hit their contracts
- __security-researchers__: identify, assess, measure and write POCs for real damage that flashloan-focused attack vectors can cause

> **Important**: This software is intended for legitimate business and research purposes only. Any use for malicious activities including but not limited to attacks on live protocols or theft of assets is strictly prohibited. Users must comply with all applicable laws, regulations, and ethical standards. See [LICENSE.md](LICENSE.md) for more details.

## Scoop for Devs

Cool tricks were possible when transient storage's 1-transaction persistence __yin__, met _flashgod_'s 1-transaction flashloan __yang__:<br/><br/>
    <img width="500" alt="Screenshot 2024-11-30 at 9 57 18 AM" src="https://github.com/user-attachments/assets/b02c523d-f908-4137-b269-63ce7d964316">
- __statelessness__: extensive use of transient storage allowed
  - 0 state variables (except the ones inherited which can be removed too)
  - upto 200x cheaper reads and writes across the transaction (max SSTORE = 20k gas against max TSTORE = 100 gas)
  - persistent metadata of providers and flashloaned assets, necessary for the recursive flashloan calls
- __yulism__: using yul wherever sensibly possible to reduce gas significantly, most notably for [decoding bytes array](https://github.com/smitrajput/flashgod/blob/main/src/Tremor.sol#L264) of pool data of all UniV3 pools and storing them in transient storage, in a way that allows for simple and quick access
- __iterable-set__: the key-value nature of transient storage allows for implementing an _Iterable-Set_ data structure using two mappings, 1 to allow adding unique assets in O(1) time, and the other to iterate over these assets through insertion order in O(n) time. This came handy in storing overlapping assets from multiple flashloan providers, uniquely.

## Project Structure

`src/`
- `Tremor.sol` - Core contract implementing aggregated flash loans across Aave, Balancer, and Uniswap V3
- `config/Addresses.sol` - Configuration file containing protocol addresses for supported chains

`test/`
- `Tremor.t.sol` - Integration tests for flash loan functionality across different chains
- `invariants/`
  - `Tremor.invariants.t.sol` - Invariant tests ensuring core safety properties
  - `handlers/Handler.sol` - Test handlers for fuzzing flash loan interactions

`foundry.toml`
- Foundry configuration file with EVM settings and test parameters

## Usage
1. Run locally:
    - `git clone git@github.com:smitrajput/flashgod.git && cd flashgod`
    - `cp .env.example .env`, then add your RPC URLs in the `.env` file
    - install foundry (follow [this section](https://book.getfoundry.sh/getting-started/installation#using-foundryup))
    - `forge install`
    - `forge test --via-ir`, should show: <img width="592" alt="Screenshot 2024-11-29 at 6 15 49 PM" src="https://github.com/user-attachments/assets/ebbcdfae-1eef-4a81-9d51-741badb603db">
2. Update [this list](https://github.com/smitrajput/flashgod/blob/main/src/config/Addresses.sol) of addresses with ones you want to flashloan
3. Time to test. Update corresponding assets and amounts in the test functions of the chains you want to flashloan from. For instance, to flashloan from Ethereum, update the `test_dominoeFlashLoans_ethereum()` function:
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L40) to update aave assets
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L51) to specify amounts for aave
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L65) to update balancer assets
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L75) to specify amounts for balancer
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L82) to update uniV3 pools
   - [here](https://github.com/smitrajput/flashgod/blob/main/test/Tremor.t.sol#L103) to specify amounts for uniV3
4. Finally, add the logic you want to execute using the aggregated flashloans to [_letsPutASmileOnThatFace()](https://github.com/smitrajput/flashgod/blob/main/src/Tremor.sol#L488)
5. Run `forge test -vv --via-ir --match-test "test_dominoeFlashLoans_ethereum()"`, for some fireworks:
  <img width="573" alt="Screenshot 2024-11-30 at 8 47 02 AM" src="https://github.com/user-attachments/assets/17be12ee-3098-4cf9-9254-b13d077f3bef">

## Future Work / Improvements
- the 7 txns becoming 1 should be a richter scale 9.0, beginning the era of cross-chain flashloans. Interesting experiments might be possible using [Polymer](https://x.com/Polymer_Labs/status/1855974277130195134) today, until we figure out atomic interop.
- support for other EVM and altEVM chains could be added
- support for more flashloan providers (dYdX?) if any, could be added
- the 2 inherited immutable variables in `Tremor.sol` from `PeripheryPayments` and `PeripheryImmutableState` can be removed and a minimal WETH deposit/withdraw, token transfer logic can be added to further reduce gas
- `Tremor.sol` can be converted to an abstract contract, making `_letsPutASmileOnThatFace()` a virtual function, which can be overriden by developers' derived contracts to add their fund-usage logic
- `Tremor.sol` could be deployed on all 7 chains as a diamond proxy contract, with 1 facet open for developers to upgrade, write their fund-usage logic, use it, and destroy it in the same txn. Call them __ephemeral__ contracts. Do bear in mind the legal risks of deploying such a contract.

## Credits
Opening GIF: [A.L.Crego](https://x.com/ALCrego_/status/1860242375118888960)

## Legal
[LICENSE.md](LICENSE.md)