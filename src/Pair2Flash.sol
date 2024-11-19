pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";

import "@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol";
import "@uniswap/v3-periphery/contracts/base/PeripheryImmutableState.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-periphery/contracts/libraries/CallbackValidation.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test, console} from "forge-std/Test.sol";

interface ITremor {
    function fire() external;
}

contract Pair2Flash is IUniswapV3FlashCallback, PeripheryPayments, Test {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;

    ISwapRouter internal immutable _swapRouter;

    address internal constant _WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    // address internal constant _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    constructor(ISwapRouter swapRouter_, address factory_, address WETH9_) PeripheryImmutableState(factory_, WETH9_) {
        _swapRouter = swapRouter_;
    }

    //fee1 is the fee of the pool from the initial borrow
    //fee2 is the fee of the first pool to arb from
    //fee3 is the fee of the second pool to arb from
    struct FlashParams {
        address token0;
        address token1;
        uint24 fee1;
        uint24 fee2;
        uint24 fee3;
        uint256 amount0;
        uint256 amount1;
    }

    // fee2 and fee3 are the two other fees associated with the two other pools of token0 and token1
    struct FlashCallbackData {
        uint256 amount0;
        uint256 amount1;
        address payer;
        uint24 poolFee2;
        uint24 poolFee3;
        PoolAddress.PoolKey poolKey;
    }

    function initFlash(
        FlashParams calldata params_,
        address pairFlash_,
        address tremor_,
        bytes calldata nextPool_,
        bytes calldata prevPool_
    ) external {
        // Move struct creation outside of function call to reduce stack depth
        FlashCallbackData memory flashData = FlashCallbackData({
            amount0: params_.amount0,
            amount1: params_.amount1,
            payer: msg.sender,
            poolKey: PoolAddress.PoolKey({token0: params_.token0, token1: params_.token1, fee: params_.fee1}),
            poolFee2: params_.fee2,
            poolFee3: params_.fee3
        });

        {
            (address prevTokenA, address prevTokenB,) = abi.decode(prevPool_, (address, address, uint16));
            uint256 prevTokenABalance = IERC20(prevTokenA).balanceOf(address(this));
            uint256 prevTokenBBalance = IERC20(prevTokenB).balanceOf(address(this));
            assembly {
                tstore(0x00, tremor_)
                tstore(0x20, pairFlash_)
                tstore(0x40, prevTokenABalance)
                tstore(0x60, prevTokenBBalance)
                tstore(0x80, calldataload(prevPool_.offset)) // prev tokenA
                tstore(0xA0, calldataload(add(prevPool_.offset, 0x20))) // prev tokenB
            }
        }
        {
            IUniswapV3Pool uniPool = IUniswapV3Pool(PoolAddress.computeAddress(factory, flashData.poolKey));
            uniPool.flash(address(this), params_.amount0, params_.amount1, abi.encode(flashData));
        }
    }

    function uniswapV3FlashCallback(uint256 fee0_, uint256 fee1_, bytes calldata data_) external override {
        FlashCallbackData memory decoded = abi.decode(data_, (FlashCallbackData));

        address token0 = decoded.poolKey.token0;
        address token1 = decoded.poolKey.token1;

        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        // end up with amountOut0 of token0 from first swap and amountOut1 of token1 from second swap
        uint256 amount0Owed = LowGasSafeMath.add(decoded.amount0, fee0_);
        uint256 amount1Owed = LowGasSafeMath.add(decoded.amount1, fee1_);

        // Add to existing balance instead of overwriting
        deal(token0, address(this), IERC20(token0).balanceOf(address(this)) + fee0_);
        deal(token1, address(this), IERC20(token1).balanceOf(address(this)) + fee1_);

        console.log(
            IERC20Metadata(token0).symbol(),
            IERC20(token0).balanceOf(address(this)) / (10 ** IERC20Metadata(token0).decimals()),
            IERC20Metadata(token1).symbol(),
            IERC20(token1).balanceOf(address(this)) / (10 ** IERC20Metadata(token1).decimals())
        );

        address tremor;
        address pairFlash;
        address prevTokenA;
        address prevTokenB;
        uint256 prevTokenABalance;
        uint256 prevTokenBBalance;
        assembly {
            tremor := tload(0x00)
            pairFlash := tload(0x20)
            prevTokenABalance := tload(0x40)
            prevTokenBBalance := tload(0x60)
            prevTokenA := tload(0x80)
            prevTokenB := tload(0xA0)
        }

        // send all tokens to tremor
        TransferHelper.safeTransfer(token0, tremor, decoded.amount0);
        TransferHelper.safeTransfer(token1, tremor, decoded.amount1);
        TransferHelper.safeTransfer(prevTokenA, tremor, prevTokenABalance);
        TransferHelper.safeTransfer(prevTokenB, tremor, prevTokenBBalance);

        ITremor(tremor).fire();

        // return tokens to pairFlash
        TransferHelper.safeTransfer(prevTokenA, pairFlash, prevTokenABalance);
        TransferHelper.safeTransfer(prevTokenB, pairFlash, prevTokenBBalance);

        if (amount0Owed > 0) pay(token0, address(this), msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(token1, address(this), msg.sender, amount1Owed);
    }
}
