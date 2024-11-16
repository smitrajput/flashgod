// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IPoolAddressesProvider, IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IFlashLoanSimpleReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IFlashLoanReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {Test, console} from "forge-std/Test.sol";

interface IPair1Flash {
    struct FlashParams {
        address token0;
        uint24 fee1;
        uint24 fee2;
        uint24 fee3;
        address token1;
        uint256 amount0;
        uint256 amount1;
    }

    function initFlash(FlashParams memory params, address _tremor) external;
}

contract Tremor is IFlashLoanReceiver {
    address internal _addressesProvider;
    address internal _pool;
    // only for logging assistance in fire()
    address[] internal _assets;

    address internal constant _WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant _USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant _FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    constructor(address addressesProvider_, address pool_) {
        _addressesProvider = addressesProvider_;
        _pool = pool_;
    }

    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(_addressesProvider);
    }

    function POOL() external view override returns (IPool) {
        // could possibly eliminate _pool state variable using this
        return IPool(_pool);
        // return ADDRESSES_PROVIDER().getPool(/*id of pool on arbitrum*/);
    }

    function dominoeFlashLoans(
        address[] calldata assets_,
        uint256[] calldata amounts_,
        address pair1Flash_,
        address pair2Flash_
    ) external {
        assembly {
            tstore(0x00, pair1Flash_)
            tstore(0x20, pair2Flash_)
        }

        _assets = assets_;

        console.log("Approving tokens...");
        assembly {
            let end := add(assets_.offset, shl(5, assets_.length))
            mstore(0x00, 0x095ea7b3) // selector for approve(address,uint256)
            mstore(0x20, and(sload(_pool.slot), 0xffffffffffffffffffffffffffffffffffffffff)) // need to mask off first 12 bytes from _pool.slot
            mstore(0x40, not(0)) // type(uint256).max approved

            for { let i := assets_.offset } lt(i, end) { i := add(i, 0x20) } {
                let success := call(gas(), calldataload(i), 0, 0x1C, 0x44, 0x60, 0x00)
                if iszero(success) { revert(0x00, 0x00) }
            }

            let interestRateModes
            mstore(interestRateModes, assets_.length)
            for { let i := 0 } lt(i, assets_.length) { i := add(i, 1) } {
                mstore(add(interestRateModes, mul(i, 0x20)), 0) // Assuming all interestRateModes are 0 for simplicity
            }

            let data
            mstore(data, 0x5cffe9de) // selector for flashLoan(address,address[],uint256[],uint256[],address,bytes,uint256)
            mstore(add(data, 0x20), address()) // need to mask off first 12 bytes from _pool.slot
            mstore(add(data, 0x40), assets_.offset) // assets
            mstore(add(data, 0x60), amounts_.offset) // amounts
            mstore(add(data, 0x80), interestRateModes) // interestRateModes
            mstore(add(data, 0xA0), 0) // onBehalfOf
            mstore(add(data, 0xC0), 0) // params
            mstore(add(data, 0xE0), 0) // referralCode

            let success :=
                call(
                    gas(),
                    and(sload(_pool.slot), 0xffffffffffffffffffffffffffffffffffffffff),
                    0,
                    add(data, 0x1C),
                    0xE4,
                    0,
                    0
                )
            if iszero(success) { revert(0, 0) }
        }
    }

    function executeOperation(
        address[] calldata assets_,
        uint256[] calldata amounts_,
        uint256[] calldata premiums_,
        address initiator_,
        bytes calldata params_
    ) external returns (bool) {
        console.log("FLASHLOAN RECEIVED");

        address pair1Flash;
        uint256 wbtcBalance = IERC20(_WBTC).balanceOf(address(this));
        uint256 usdcBalance = IERC20(_USDC).balanceOf(address(this));
        uint256 wethBalance = IERC20(_WETH).balanceOf(address(this));

        assembly {
            pair1Flash := tload(0x00)
            tstore(0x40, wbtcBalance)
            tstore(0x60, usdcBalance)
            tstore(0x80, wethBalance)
        }

        // initiate uniV3 flash loans
        IUniswapV3Pool uniPool = IUniswapV3Pool(
            PoolAddress.computeAddress(_FACTORY, PoolAddress.PoolKey({token0: _WBTC, token1: _WETH, fee: 500}))
        );

        IPair1Flash(pair1Flash).initFlash(
            IPair1Flash.FlashParams({
                token0: _WBTC, // could avoid hardcoding tokens here
                token1: _WETH, // could avoid hardcoding tokens here
                fee1: 500,
                amount0: (IERC20(_WBTC).balanceOf(address(uniPool)) * 99) / 100, // could test withdrawable limits further here
                amount1: (IERC20(_WETH).balanceOf(address(uniPool)) * 99) / 100, // could test withdrawable limits further here
                fee2: 3000,
                fee3: 10000
            }),
            address(this)
        );
        return true;
    }

    function tabulate() external {
        // use this fn to note down balances of tokens sent from each PairFlash (pool), to be able to return them correctly
        // and more importantly for generalised tokens / univ3 pools
    }

    function fire() external {
        console.log("FIRING");
        for (uint256 i = 0; i < _assets.length; ++i) {
            console.log(
                IERC20Metadata(_assets[i]).symbol(),
                IERC20(_assets[i]).balanceOf(address(this)) / (10 ** IERC20Metadata(_assets[i]).decimals())
            );
        }

        // do interesting stuff here with ~$1B of flashloaned money

        // Return the difference between current balances and initial balances back to PairFlash2
        address pair2Flash;
        uint256 wbtcBalance;
        uint256 usdcBalance;
        uint256 wethBalance;
        assembly {
            pair2Flash := tload(0x20)
            wbtcBalance := tload(0x40)
            usdcBalance := tload(0x60)
            wethBalance := tload(0x80)
        }

        TransferHelper.safeTransfer(_USDC, pair2Flash, IERC20(_USDC).balanceOf(address(this)) - usdcBalance);
        TransferHelper.safeTransfer(_WBTC, pair2Flash, IERC20(_WBTC).balanceOf(address(this)) - wbtcBalance);
        TransferHelper.safeTransfer(_WETH, pair2Flash, IERC20(_WETH).balanceOf(address(this)) - wethBalance);
    }
}
