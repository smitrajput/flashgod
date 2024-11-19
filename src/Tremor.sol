// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IPoolAddressesProvider, IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IFlashLoanSimpleReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IFlashLoanReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IFlashLoanRecipient} from "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {Pair1Flash} from "./Pair1Flash.sol";

import {Test, console, Vm} from "forge-std/Test.sol";

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

    function initFlash(FlashParams memory params, address _tremor, bytes calldata nextPool_) external;
}

contract Tremor is IFlashLoanReceiver, IFlashLoanRecipient, Test {
    address internal _addressesProvider;
    address internal _pool;
    IVault internal _vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    ISwapRouter internal _swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    // only for logging assistance in fire()
    address[] internal _assets;
    UniFlashLoanBalances[] internal _uniFlashLoanBalances;

    address internal constant _WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant _USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant _FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    struct UniFlashLoanBalances {
        address pairFlash;
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
    }

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

    /// @dev balancer flash-loan callback
    function receiveFlashLoan(
        IERC20[] memory tokens_,
        uint256[] memory amounts_,
        uint256[] memory feeAmounts_,
        bytes memory userData_
    ) external override {
        require(msg.sender == address(_vault));

        {
            for (uint256 i = 0; i < tokens_.length; i++) {
                console.log(
                    "Balance of token",
                    IERC20Metadata(address(tokens_[i])).symbol(),
                    "is",
                    tokens_[i].balanceOf(address(this))
                );
            }
            for (uint256 i = 0; i < tokens_.length; i++) {
                uint256 currentBalance = tokens_[i].balanceOf(address(this));
                deal(address(tokens_[i]), address(this), currentBalance + feeAmounts_[i]);
            }
        }

        address pair1Flash;
        // assembly {
        //     pair1Flash := tload(0x00)
        // }
        bytes[] memory uniPools = abi.decode(userData_, (bytes[]));
        if (uniPools.length > 0) {
            pair1Flash = address(new Pair1Flash(_swapRouter, _FACTORY, _WETH));
            (address tokenA, address tokenB, uint16 feeAB) = abi.decode(uniPools[0], (address, address, uint16));

            // initiate uniV3 flash loans
            IUniswapV3Pool uniPool = IUniswapV3Pool(
                PoolAddress.computeAddress(_FACTORY, PoolAddress.PoolKey({token0: tokenA, token1: tokenB, fee: feeAB}))
            );

            IPair1Flash(pair1Flash).initFlash(
                IPair1Flash.FlashParams({
                    token0: tokenA,
                    token1: tokenB,
                    fee1: feeAB,
                    amount0: (IERC20(tokenA).balanceOf(address(uniPool)) * 99) / 100, // could test withdrawable limits further here
                    amount1: (IERC20(tokenB).balanceOf(address(uniPool)) * 99) / 100, // could test withdrawable limits further here
                    fee2: 3000,
                    fee3: 10000
                }),
                address(this),
                uniPools,
                1
            );
        }

        {
            for (uint256 i = 0; i < tokens_.length; i++) {
                TransferHelper.safeTransfer(address(tokens_[i]), address(_vault), amounts_[i] + feeAmounts_[i]);
            }
        }
    }

    function dominoeFlashLoans(
        address[] calldata aaveAssets_,
        uint256[] calldata aaveAmounts_,
        address[] calldata balancerAssets_,
        bytes[] calldata uniPools_,
        address pair1Flash_,
        address pair2Flash_
    ) external {
        // assembly {
        //     tstore(0x00, pair1Flash_)
        //     tstore(0x20, pair2Flash_)
        // }
        _assets = aaveAssets_;

        console.log("Approving tokens...");
        for (uint256 i = 0; i < aaveAssets_.length; ++i) {
            IERC20(aaveAssets_[i]).approve(_pool, type(uint256).max);
        }

        uint256[] memory interestRateModes = new uint256[](aaveAssets_.length);

        console.log("Calling AAVE flash loan...");
        IPool(_pool).flashLoan(
            address(this),
            aaveAssets_,
            aaveAmounts_,
            interestRateModes,
            address(0),
            abi.encode(balancerAssets_, uniPools_),
            0
        );
    }

    /// @dev aave flash-loan callback
    function executeOperation(
        address[] calldata assets_,
        uint256[] calldata amounts_,
        uint256[] calldata premiums_,
        address initiator_,
        bytes calldata params_
    ) external returns (bool) {
        console.log("FLASHLOAN RECEIVED");

        (address[] memory balancerAssets, bytes[] memory uniPools) = abi.decode(params_, (address[], bytes[]));

        console.log("Balancer Assets:");
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            console.log(balancerAssets[i]);
        }
        console.log("Uniswap Assets:");
        for (uint256 i = 0; i < uniPools.length; i++) {
            console.logBytes(uniPools[i]);
        }

        // call balancer flash loan and from its callback, call uniswap flash loans
        uint256[] memory balancerAmounts = new uint256[](balancerAssets.length);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balancerAmounts[i] = IERC20(balancerAssets[i]).balanceOf(address(_vault));
        }

        // Convert address[] to IERC20[] before calling flashLoan
        IERC20[] memory balTokens = new IERC20[](balancerAssets.length);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balTokens[i] = IERC20(balancerAssets[i]);
        }
        _vault.flashLoan(this, balTokens, balancerAmounts, abi.encode(uniPools));

        return true;
    }

    /// @dev add onlyPairFlash permission
    function registerUniFlashLoanBalances(
        address pairFlash_,
        address token0_,
        address token1_,
        uint256 amount0_,
        uint256 amount1_
    ) external {
        // use this fn to note down balances of tokens sent from each PairFlash (pool), to be able to return them correctly
        // and more importantly for generalised tokens / univ3 pools
        _uniFlashLoanBalances.push(
            UniFlashLoanBalances({
                pairFlash: pairFlash_,
                token0: token0_,
                token1: token1_,
                amount0: amount0_,
                amount1: amount1_
            })
        );
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

        for (uint256 i = 0; i < _uniFlashLoanBalances.length; ++i) {
            TransferHelper.safeTransfer(
                _uniFlashLoanBalances[i].token0, _uniFlashLoanBalances[i].pairFlash, _uniFlashLoanBalances[i].amount0
            );
            TransferHelper.safeTransfer(
                _uniFlashLoanBalances[i].token1, _uniFlashLoanBalances[i].pairFlash, _uniFlashLoanBalances[i].amount1
            );
        }
    }
}
