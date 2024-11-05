// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
// import {IPoolAddressesProvider, IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
// import {IFlashLoanReceiver} from "@aave/core-v3/contracts/interfaces/IFlashLoanReceiver.sol";

contract Tremor is IFlashLoanReceiver {

    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
    }

    function POOL() external view returns (IPool) {
        return IPool(0x794a61358D6845594c8fCcD7fC5086eA5CC6243D);
        // return ADDRESSES_PROVIDER().getPool(/*id of pool on arbitrum*/);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        return true;
    }

    function callFlashLoan(uint256 amount) external {
        bytes memory params = abi.encode(amount);
        address[] memory assets = new address[](5);
        assets[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum
        assets[1] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; // WBTC on Arbitrum
        assets[2] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC on Arbitrum
        assets[3] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT on Arbitrum
        assets[4] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI on Arbitrum
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 6_900 * 1e18;    // WETH max flash loan amount
        amounts[1] = 440 * 1e8;       // WBTC max flash loan amount (8 decimals)
        amounts[2] = 20_000_000 * 1e6; // USDC max flash loan amount (6 decimals)
        amounts[3] = 20_000_000 * 1e6; // USDT max flash loan amount (6 decimals) 
        amounts[4] = 20_000_000 * 1e18; // DAI max flash loan amount
        uint256[] memory interestRateModes = new uint256[](5);
        POOL().flashLoan(address(this), assets, amounts, interestRateModes, address(0), bytes(""), 0);
        console.log("WETH balance:", IERC20(assets[0]).balanceOf(address(this)));
        console.log("WBTC balance:", IERC20(assets[1]).balanceOf(address(this)));
        console.log("USDC balance:", IERC20(assets[2]).balanceOf(address(this)));
        console.log("USDT balance:", IERC20(assets[3]).balanceOf(address(this)));
        console.log("DAI balance:", IERC20(assets[4]).balanceOf(address(this)));
    }
}
