// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {IPoolAddressesProvider, IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IFlashLoanSimpleReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IFlashLoanReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Tremor is IFlashLoanReceiver {
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

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        console.log("FLASHLOAN RECEIVED");
        for (uint256 i = 0; i < assets.length; i++) {
            console.log(
                IERC20Metadata(assets[i]).symbol(),
                IERC20(assets[i]).balanceOf(address(this)) / (10 ** IERC20Metadata(assets[i]).decimals())
            );
        }
        return true;
    }

    function callFlashLoan(address[] calldata assets, uint256[] calldata amounts) external {
        console.log("Approving tokens...");
        for (uint256 i = 0; i < assets.length; ++i) {
            IERC20(assets[i]).approve(address(this.POOL()), type(uint256).max);
        }
        uint256[] memory interestRateModes = new uint256[](assets.length);
        console.log("Calling flash loan...");
        this.POOL().flashLoan(address(this), assets, amounts, interestRateModes, address(0), bytes(""), 0);
    }
}
