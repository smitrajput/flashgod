// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {IPoolAddressesProvider, IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IFlashLoanSimpleReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TremorSimple is IFlashLoanSimpleReceiver {
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

    // function callFlashLoan(address[] calldata assets, uint256[] calldata amounts) external {
    //     console.log("Approving tokens...");
    //     for (uint256 i = 0; i < assets.length; ++i) {
    //         IERC20(assets[i]).approve(address(this.POOL()), type(uint256).max);
    //     }
    //     uint256[] memory interestRateModes = new uint256[](assets.length);
    //     console.log("Calling flash loan...");
    //     console.log("amounts[0]:", amounts[0]);
    //     console.log("amounts[1]:", amounts[1]);
    //     this.POOL().flashLoan(address(this), assets, amounts, interestRateModes, address(0), bytes(""), 0);
    //     console.log("WETH balance:", IERC20(assets[0]).balanceOf(address(this)) / 1e18);
    //     console.log("WBTC balance:", IERC20(assets[1]).balanceOf(address(this)) / 1e8);
    //     // console.log("USDC balance:", IERC20(assets[2]).balanceOf(address(this)));
    //     // console.log("USDT balance:", IERC20(assets[3]).balanceOf(address(this)));
    //     // console.log("DAI balance:", IERC20(assets[4]).balanceOf(address(this)));
    // }

    function callSingleFlashLoan(address asset, uint256 amount) external {
        IERC20(asset).approve(address(this.POOL()), type(uint256).max);
        console.log("Approved amount:", IERC20(asset).allowance(address(this), address(this.POOL())));
        this.POOL().flashLoanSimple(address(this), asset, amount, bytes(""), 0);
        console.log("ZING");
    }
}
