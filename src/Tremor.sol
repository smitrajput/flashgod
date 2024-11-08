// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {IPoolAddressesProvider, IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IFlashLoanSimpleReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Tremor is IFlashLoanSimpleReceiver {
    address public addressesProvider;
    address public pool;

    constructor(address _addressesProvider, address _pool) {
        addressesProvider = _addressesProvider;
        pool = _pool;
    }

    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(addressesProvider);
    }

    function POOL() external view override returns (IPool) {
        return IPool(pool);
        // return ADDRESSES_PROVIDER().getPool(/*id of pool on arbitrum*/);
    }

    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params)
        external
        returns (bool)
    {
        console.log("FLASHLOAN RECEIVED");
        console.log("Asset balance:", IERC20(asset).balanceOf(address(this)));
        return true;
    }

    // function callFlashLoan() external {
    //     // bytes memory params = abi.encode();
    //     address[] memory assets = new address[](5);
    //     assets[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum
    //     assets[1] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; // WBTC on Arbitrum
    //     assets[2] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC on Arbitrum
    //     assets[3] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT on Arbitrum
    //     assets[4] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI on Arbitrum
    //     uint256[] memory amounts = new uint256[](5);
    //     amounts[0] = 6_900 * 1e18;    // WETH max flash loan amount
    //     amounts[1] = 440 * 1e8;       // WBTC max flash loan amount (8 decimals)
    //     amounts[2] = 20_000_000 * 1e6; // USDC max flash loan amount (6 decimals)
    //     amounts[3] = 20_000_000 * 1e6; // USDT max flash loan amount (6 decimals)
    //     amounts[4] = 20_000_000 * 1e18; // DAI max flash loan amount
    //     uint256[] memory interestRateModes = new uint256[](5);
    //     this.POOL().flashLoan(address(this), assets, amounts, interestRateModes, address(0), bytes(""), 0);
    //     console.log("WETH balance:", IERC20(assets[0]).balanceOf(address(this)));
    //     console.log("WBTC balance:", IERC20(assets[1]).balanceOf(address(this)));
    //     console.log("USDC balance:", IERC20(assets[2]).balanceOf(address(this)));
    //     console.log("USDT balance:", IERC20(assets[3]).balanceOf(address(this)));
    //     console.log("DAI balance:", IERC20(assets[4]).balanceOf(address(this)));
    // }

    function callSingleFlashLoan(address asset, uint256 amount) external {
        IERC20(asset).approve(address(this.POOL()), type(uint256).max);
        console.log("Approved amount:", IERC20(asset).allowance(address(this), address(this.POOL())));
        this.POOL().flashLoanSimple(address(this), asset, amount, bytes(""), 0);
        console.log("ZING");
    }
}
