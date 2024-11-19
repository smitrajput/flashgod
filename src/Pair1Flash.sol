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
import {Test, console} from "forge-std/Test.sol";

interface IPair2Flash {
    struct FlashParams {
        address token0;
        address token1;
        uint24 fee1;
        uint24 fee2;
        uint24 fee3;
        uint256 amount0;
        uint256 amount1;
    }

    function initFlash(
        FlashParams memory params,
        address _pairFlash,
        address _tremor,
        bytes calldata nextPool_,
        bytes calldata prevPool_
    ) external;
}

contract Pair1Flash is IUniswapV3FlashCallback, PeripheryPayments, Test {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;

    ISwapRouter internal immutable _swapRouter;
    IPair2Flash internal immutable _pair2Flash;
    address internal immutable _factory;

    address internal constant _USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    constructor(ISwapRouter swapRouter_, address factory_, address WETH9_, address payable pair2Flash_)
        PeripheryImmutableState(factory_, WETH9_)
    {
        _swapRouter = swapRouter_;
        _factory = factory_;
        _pair2Flash = IPair2Flash(pair2Flash_);
    }

    // fee1 is the fee of the pool from the initial borrow
    // fee2 is the fee of the first pool to arb from
    // fee3 is the fee of the second pool to arb from
    // efficient packing of params
    struct FlashParams {
        address token0;
        uint24 fee1;
        uint24 fee2;
        uint24 fee3;
        address token1;
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
        address tremor_,
        bytes calldata nextPool_,
        bytes calldata prevPool_
    ) external {
        assembly {
            tstore(0, tremor_)
            tstore(0x20, calldataload(nextPool_.offset)) // tokenA
            tstore(0x40, calldataload(add(nextPool_.offset, 0x20))) // tokenB
            tstore(0x60, calldataload(add(nextPool_.offset, 0x40))) // feeAB
        }
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params_.token0, token1: params_.token1, fee: params_.fee1});
        IUniswapV3Pool uniPool = IUniswapV3Pool(PoolAddress.computeAddress(_factory, poolKey));
        uniPool.flash(
            address(this),
            params_.amount0,
            params_.amount1,
            abi.encode(
                FlashCallbackData({
                    amount0: params_.amount0,
                    amount1: params_.amount1,
                    payer: msg.sender,
                    poolKey: poolKey,
                    poolFee2: params_.fee2,
                    poolFee3: params_.fee3
                })
            )
        );
    }

    function uniswapV3FlashCallback(uint256 fee0_, uint256 fee1_, bytes calldata data_) external override {
        FlashCallbackData memory decoded = abi.decode(data_, (FlashCallbackData));

        address token0 = decoded.poolKey.token0;
        address token1 = decoded.poolKey.token1;

        console.log(
            IERC20Metadata(token0).symbol(),
            IERC20(token0).balanceOf(address(this)) / (10 ** IERC20Metadata(token0).decimals()),
            IERC20Metadata(token1).symbol(),
            IERC20(token1).balanceOf(address(this)) / (10 ** IERC20Metadata(token1).decimals())
        );

        CallbackValidation.verifyCallback(_factory, decoded.poolKey);

        TransferHelper.safeApprove(token0, address(_swapRouter), decoded.amount0);
        TransferHelper.safeApprove(token1, address(_swapRouter), decoded.amount1);

        // end up with amountOut0 of token0 from first swap and amountOut1 of token1 from second swap
        uint256 amount0Owed = LowGasSafeMath.add(decoded.amount0, fee0_);
        uint256 amount1Owed = LowGasSafeMath.add(decoded.amount1, fee1_);

        // simulate minting fees to existing balance
        deal(token0, address(this), IERC20(token0).balanceOf(address(this)) + fee0_);
        deal(token1, address(this), IERC20(token1).balanceOf(address(this)) + fee1_);

        TransferHelper.safeTransfer(token0, address(_pair2Flash), IERC20(token0).balanceOf(address(this)));
        TransferHelper.safeTransfer(token1, address(_pair2Flash), IERC20(token1).balanceOf(address(this)));

        address tremor;
        address tokenA;
        address tokenB;
        uint16 feeAB;
        assembly {
            tremor := tload(0)
            tokenA := tload(0x20)
            tokenB := tload(0x40)
            feeAB := tload(0x60)
        }

        IUniswapV3Pool uniPool = IUniswapV3Pool(
            PoolAddress.computeAddress(_factory, PoolAddress.PoolKey({token0: tokenA, token1: tokenB, fee: feeAB}))
        );
        _pair2Flash.initFlash(
            IPair2Flash.FlashParams({
                token0: tokenA,
                token1: tokenB,
                fee1: feeAB,
                amount0: IERC20(tokenA).balanceOf(address(uniPool)) * 999 / 1000, // could test withdrawable limits further here
                amount1: IERC20(tokenB).balanceOf(address(uniPool)) * 999 / 1000, // could test withdrawable limits further here
                fee2: 3000,
                fee3: 10000
            }),
            address(this),
            tremor,
            bytes(""),
            abi.encode(token0, token1, 0 /* fee1 isn't required atm */ )
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
