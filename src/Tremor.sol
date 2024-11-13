// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {IPoolAddressesProvider, IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IFlashLoanSimpleReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IFlashLoanReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PairFlash} from "./PairFlash.sol";
import {FlashParams} from "./PairFlash.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract Tremor is IFlashLoanReceiver {
    address public addressesProvider;
    address public pool;
    address payable public pairFlash;
    address payable public pairFlash2;
    address public constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address[] public assets;

    uint256 public wbtcBalance;
    uint256 public usdcBalance;
    uint256 public wethBalance;

    constructor(address _addressesProvider, address _pool, address payable _pairFlash, address payable _pairFlash2) {
        addressesProvider = _addressesProvider;
        pool = _pool;
        pairFlash = _pairFlash;
        pairFlash2 = _pairFlash2;
    }

    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(addressesProvider);
    }

    function POOL() external view override returns (IPool) {
        return IPool(pool);
        // return ADDRESSES_PROVIDER().getPool(/*id of pool on arbitrum*/);
    }

    function executeOperation(
        address[] calldata _assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        console.log("FLASHLOAN RECEIVED");
        assets = _assets;

        wbtcBalance = IERC20(WBTC).balanceOf(address(this));
        usdcBalance = IERC20(USDC).balanceOf(address(this));
        wethBalance = IERC20(WETH).balanceOf(address(this));

        // initiate uniV3 flash loans
        IUniswapV3Pool pool = IUniswapV3Pool(
            PoolAddress.computeAddress(FACTORY, PoolAddress.PoolKey({token0: WBTC, token1: WETH, fee: 500}))
        );

        PairFlash(pairFlash).initFlash(
            FlashParams({
                token0: WBTC,
                token1: WETH,
                fee1: 500,
                amount0: (IERC20(WBTC).balanceOf(address(pool)) * 99) / 100,
                amount1: (IERC20(WETH).balanceOf(address(pool)) * 99) / 100,
                fee2: 3000,
                fee3: 10000
            }),
            address(this)
        );
        return true;
    }

    function punish() external {
        console.log("PUNISHING");
        for (uint256 i = 0; i < assets.length; i++) {
            console.log(
                IERC20Metadata(assets[i]).symbol(),
                IERC20(assets[i]).balanceOf(address(this)) / (10 ** IERC20Metadata(assets[i]).decimals())
            );
        }
        // Return the difference between current balances and initial balances back to PairFlash2
        TransferHelper.safeTransfer(USDC, pairFlash2, IERC20(USDC).balanceOf(address(this)) - usdcBalance);
        TransferHelper.safeTransfer(WBTC, pairFlash2, IERC20(WBTC).balanceOf(address(this)) - wbtcBalance);
        TransferHelper.safeTransfer(WETH, pairFlash2, IERC20(WETH).balanceOf(address(this)) - wethBalance);
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
