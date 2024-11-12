pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol";
import "@uniswap/v3-periphery/contracts/base/PeripheryImmutableState.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-periphery/contracts/libraries/CallbackValidation.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PairFlash2} from "./PairFlash2.sol";
import {Test, console} from "forge-std/Test.sol";

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

contract PairFlash is IUniswapV3FlashCallback, PeripheryPayments, Test {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;

    ISwapRouter public immutable swapRouter;
    PairFlash2 public immutable pairFlash2;
    address public factory_;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public tremor;

    constructor(ISwapRouter _swapRouter, address _factory, address _WETH9, address payable _pairFlash2)
        PeripheryImmutableState(_factory, _WETH9)
    {
        swapRouter = _swapRouter;
        factory_ = _factory;
        pairFlash2 = PairFlash2(_pairFlash2);
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

    function initFlash(FlashParams memory params, address _tremor) external {
        tremor = _tremor;
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee1});
        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(factory_, poolKey));
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

        console.log(
            IERC20Metadata(token0).symbol(),
            IERC20(token0).balanceOf(address(this)) / (10 ** IERC20Metadata(token0).decimals()),
            IERC20Metadata(token1).symbol(),
            IERC20(token1).balanceOf(address(this)) / (10 ** IERC20Metadata(token1).decimals())
        );

        CallbackValidation.verifyCallback(factory_, decoded.poolKey);

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

        console.log("amount0Owed:", amount0Owed);
        console.log("token0 balance:", IERC20(token0).balanceOf(address(this)));

        TransferHelper.safeTransfer(token0, address(pairFlash2), IERC20(token0).balanceOf(address(this)));
        TransferHelper.safeTransfer(token1, address(pairFlash2), IERC20(token1).balanceOf(address(this)));

        IUniswapV3Pool pool = IUniswapV3Pool(
            PoolAddress.computeAddress(factory_, PoolAddress.PoolKey({token0: WETH9, token1: USDC, fee: 500}))
        );

        pairFlash2.initFlash2(
            PairFlash2.FlashParams({
                token0: WETH9,
                token1: USDC,
                fee1: 500,
                amount0: IERC20(WETH9).balanceOf(address(pool)) * 999 / 1000,
                amount1: IERC20(USDC).balanceOf(address(pool)) * 999 / 1000,
                fee2: 3000,
                fee3: 10000
            }),
            address(this),
            tremor
        );

        if (amount0Owed > 0) pay(token0, address(this), msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(token1, address(this), msg.sender, amount1Owed);
    }
}

// profitable check
// exactInputSingle will fail if this amount not met
// uint256 amount1Min = LowGasSafeMath.add(decoded.amount1, fee1);
// uint256 amount0Min = LowGasSafeMath.add(decoded.amount0, fee0);

// // call exactInputSingle for swapping token1 for token0 in pool w/fee2
// uint256 amountOut0 = swapRouter.exactInputSingle(
//     ISwapRouter.ExactInputSingleParams({
//         tokenIn: token1,
//         tokenOut: token0,
//         fee: decoded.poolFee2,
//         recipient: address(this),
//         deadline: block.timestamp + 200,
//         amountIn: decoded.amount1,
//         amountOutMinimum: amount0Min,
//         sqrtPriceLimitX96: 0
//     })
// );

// // call exactInputSingle for swapping token0 for token 1 in pool w/fee3
// uint256 amountOut1 = swapRouter.exactInputSingle(
//     ISwapRouter.ExactInputSingleParams({
//         tokenIn: token0,
//         tokenOut: token1,
//         fee: decoded.poolFee3,
//         recipient: address(this),
//         deadline: block.timestamp + 200,
//         amountIn: decoded.amount0,
//         amountOutMinimum: amount1Min,
//         sqrtPriceLimitX96: 0
//     })
// );

// // if profitable pay profits to payer
// if (amountOut0 > amount0Owed) {
//     uint256 profit0 = LowGasSafeMath.sub(amountOut0, amount0Owed);

//     TransferHelper.safeApprove(token0, address(this), profit0);
//     pay(token0, address(this), decoded.payer, profit0);
// }
// if (amountOut1 > amount1Owed) {
//     uint256 profit1 = LowGasSafeMath.sub(amountOut1, amount1Owed);
//     TransferHelper.safeApprove(token0, address(this), profit1);
//     pay(token1, address(this), decoded.payer, profit1);
// }
