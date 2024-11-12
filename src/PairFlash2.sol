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
import {Tremor} from "./Tremor.sol";

import {Test, console} from "forge-std/Test.sol";

contract PairFlash2 is IUniswapV3FlashCallback, PeripheryPayments, Test {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;

    address public constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    ISwapRouter public immutable swapRouter;
    uint256 public wethBalance;
    address public pairFlash;
    address public tremor_;

    constructor(ISwapRouter _swapRouter, address _factory, address _WETH9) PeripheryImmutableState(_factory, _WETH9) {
        swapRouter = _swapRouter;
    }

    //fee1 is the fee of the pool from the initial borrow
    //fee2 is the fee of the first pool to arb from
    //fee3 is the fee of the second pool to arb from
    struct FlashParams {
        address token0;
        address token1;
        uint24 fee1;
        uint256 amount0;
        uint256 amount1;
        uint24 fee2;
        uint24 fee3;
    }

    // fee2 and fee3 are the two other fees associated with the two other pools of token0 and token1
    struct FlashCallbackData {
        uint256 amount0;
        uint256 amount1;
        address payer;
        PoolAddress.PoolKey poolKey;
        uint24 poolFee2;
        uint24 poolFee3;
    }

    function initFlash2(FlashParams memory params, address _pairFlash, address _tremor) external {
        pairFlash = _pairFlash;
        tremor_ = _tremor;
        // use tstore / tload to save some gas
        wethBalance = IERC20(WETH).balanceOf(address(this));
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee1});
        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
        pool.flash(
            address(this),
            params.amount0,
            params.amount1,
            abi.encode(
                FlashCallbackData({
                    amount0: params.amount0,
                    amount1: params.amount1,
                    payer: msg.sender,
                    poolKey: poolKey,
                    poolFee2: params.fee2,
                    poolFee3: params.fee3
                })
            )
        );
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external override {
        FlashCallbackData memory decoded = abi.decode(data, (FlashCallbackData));

        address token0 = decoded.poolKey.token0;
        address token1 = decoded.poolKey.token1;

        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        TransferHelper.safeApprove(token0, address(swapRouter), decoded.amount0);
        TransferHelper.safeApprove(token1, address(swapRouter), decoded.amount1);

        // end up with amountOut0 of token0 from first swap and amountOut1 of token1 from second swap
        uint256 amount0Owed = LowGasSafeMath.add(decoded.amount0, fee0);
        uint256 amount1Owed = LowGasSafeMath.add(decoded.amount1, fee1);

        uint256 currentBalance0 = IERC20(token0).balanceOf(address(this));
        uint256 currentBalance1 = IERC20(token1).balanceOf(address(this));

        // Add to existing balance instead of overwriting
        deal(token0, address(this), currentBalance0 + fee0);
        deal(token1, address(this), currentBalance1 + fee1);

        console.log(
            IERC20Metadata(token0).symbol(),
            IERC20(token0).balanceOf(address(this)) / (10 ** IERC20Metadata(token0).decimals()),
            IERC20Metadata(token1).symbol(),
            IERC20(token1).balanceOf(address(this)) / (10 ** IERC20Metadata(token1).decimals())
        );
        console.log("WBTC", IERC20(WBTC).balanceOf(address(this)) / (10 ** 8));

        // do interesting stuff here
        TransferHelper.safeTransfer(token0, tremor_, IERC20(token0).balanceOf(address(this)));
        TransferHelper.safeTransfer(token1, tremor_, IERC20(token1).balanceOf(address(this)));
        TransferHelper.safeTransfer(WBTC, tremor_, IERC20(WBTC).balanceOf(address(this)));

        Tremor(tremor_).punish();
        // return tokens to pairFlash
        TransferHelper.safeTransfer(WBTC, pairFlash, IERC20(WBTC).balanceOf(address(this)));
        TransferHelper.safeTransfer(WETH, pairFlash, wethBalance);

        if (amount0Owed > 0) pay(token0, address(this), msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(token1, address(this), msg.sender, amount1Owed);
    }
}
