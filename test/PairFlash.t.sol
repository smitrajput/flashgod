pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {PairFlash} from "../src/PairFlash.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract PairFlashTest is Test {
    PairFlash public pairFlash;
    ISwapRouter public swapRouter;

    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address public constant WE_ETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant WSTETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address public constant USDT = 0xfD086BC7cD4c4ca33BD5C38ec837347e8A75A05d;
    address public constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address public constant LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address public constant RETH = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8;

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

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));
        vm.selectFork(forkId);

        swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        pairFlash = new PairFlash(
            swapRouter, 0x1F98431c8aD98523631AE4a59f267346ea31F984, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
        );
    }

    function test_initFlash() public {
        pairFlash.initFlash(
            FlashParams({
                token0: WBTC,
                token1: WETH,
                fee1: 500,
                amount0: 150 * 1e8,
                amount1: 10_000 * 1e18,
                fee2: 3000,
                fee3: 10000
            })
        );
    }
}
