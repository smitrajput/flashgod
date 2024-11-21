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
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";
import "@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol";
import "@uniswap/v3-periphery/contracts/base/PeripheryImmutableState.sol";
import "@uniswap/v3-periphery/contracts/libraries/CallbackValidation.sol";

import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IFlashLoanRecipient} from "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import {IERC20 as IERC20_BAL} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {console} from "forge-std/Test.sol";

contract Tremor is IFlashLoanReceiver, IFlashLoanRecipient, IUniswapV3FlashCallback, PeripheryPayments {
    address internal _addressesProvider;
    IPool internal _aavePool;
    address internal _uniV3Factory;
    IVault internal _balancerVault;
    ISwapRouter internal _uniswapRouter;
    bytes[] internal _uniPools;
    // only for logging assistance in _letsPutASmileOnThatFace()
    address[] internal _assets;

    struct UniFlashLoanBalances {
        address pairFlash;
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
    }

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

    constructor(
        address addressesProvider_,
        address aavePool_,
        address uniV3Factory_,
        address swapRouter_,
        address balVault_,
        address WETH_
    ) PeripheryImmutableState(uniV3Factory_, WETH_) {
        _addressesProvider = addressesProvider_;
        _aavePool = IPool(aavePool_);
        _uniV3Factory = uniV3Factory_;
        _uniswapRouter = ISwapRouter(swapRouter_);
        _balancerVault = IVault(balVault_);
    }

    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(_addressesProvider);
    }

    function POOL() external view override returns (IPool) {
        return _aavePool;
    }

    function dominoeFlashLoans(
        address[] calldata aaveAssets_,
        uint256[] calldata aaveAmounts_,
        address[] calldata balancerAssets_,
        bytes[] calldata uniPools_
    ) external {
        _assets = aaveAssets_;

        for (uint256 i = 0; i < aaveAssets_.length; ++i) {
            IERC20(aaveAssets_[i]).approve(address(_aavePool), type(uint256).max);
        }

        uint256[] memory interestRateModes = new uint256[](aaveAssets_.length);
        console.log("Calling AAVE flash loan...");
        _aavePool.flashLoan(
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
        console.log("Aave flashloan received -----------------");

        for (uint256 i = 0; i < _assets.length; ++i) {
            console.log(
                IERC20Metadata(_assets[i]).symbol(), amounts_[i] / (10 ** IERC20Metadata(_assets[i]).decimals())
            );
        }

        (address[] memory balancerAssets, bytes[] memory uniPools) = abi.decode(params_, (address[], bytes[]));
        // call balancer flash loan and from its callback, call uniswap flash loans
        uint256[] memory balancerAmounts = new uint256[](balancerAssets.length);
        // TODO: fix IERC20_BAL quirk
        IERC20_BAL[] memory balTokens = new IERC20_BAL[](balancerAssets.length);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balancerAmounts[i] = IERC20(balancerAssets[i]).balanceOf(address(_balancerVault));
            balTokens[i] = IERC20_BAL(balancerAssets[i]);
        }
        _balancerVault.flashLoan(this, balTokens, balancerAmounts, abi.encode(uniPools));
        return true;
    }

    /// @dev balancer flash-loan callback
    function receiveFlashLoan(
        IERC20_BAL[] memory tokens_,
        uint256[] memory amounts_,
        uint256[] memory feeAmounts_,
        bytes memory userData_
    ) external override {
        require(msg.sender == address(_balancerVault));

        console.log("Balancer flashloan received -----------------");
        for (uint256 i = 0; i < tokens_.length; i++) {
            console.log(
                IERC20Metadata(address(tokens_[i])).symbol(),
                amounts_[i] / (10 ** IERC20Metadata(address(tokens_[i])).decimals())
            );
        }

        // initiate uniV3 flash loans
        bytes[] memory uniPools = abi.decode(userData_, (bytes[]));
        if (uniPools.length > 0) {
            console.log("Uniswap flashloans initiated -----------------");
            // TODO: tstore this
            _uniPools = uniPools;
            (address tokenA, address tokenB, uint16 feeAB) = abi.decode(uniPools[0], (address, address, uint16));

            IUniswapV3Pool uniPool = IUniswapV3Pool(
                PoolAddress.computeAddress(
                    _uniV3Factory, PoolAddress.PoolKey({token0: tokenA, token1: tokenB, fee: feeAB})
                )
            );
            _initFlash(
                FlashParams({
                    token0: tokenA,
                    token1: tokenB,
                    fee1: feeAB,
                    amount0: (IERC20(tokenA).balanceOf(address(uniPool)) * 99) / 100, // could test withdrawable limits further here
                    amount1: (IERC20(tokenB).balanceOf(address(uniPool)) * 99) / 100, // could test withdrawable limits further here
                    fee2: 3000,
                    fee3: 10000
                }),
                1
            );
        }

        // return loan to balancer vault
        for (uint256 i = 0; i < tokens_.length; i++) {
            TransferHelper.safeTransfer(address(tokens_[i]), address(_balancerVault), amounts_[i] + feeAmounts_[i]);
        }
    }

    function _initFlash(FlashParams memory params_, uint256 nextPoolIndex_) internal {
        assembly {
            tstore(0x20, nextPoolIndex_)
        }
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params_.token0, token1: params_.token1, fee: params_.fee1});
        IUniswapV3Pool uniPool = IUniswapV3Pool(PoolAddress.computeAddress(_uniV3Factory, poolKey));
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
            decoded.amount0 / (10 ** IERC20Metadata(token0).decimals()),
            IERC20Metadata(token1).symbol(),
            decoded.amount1 / (10 ** IERC20Metadata(token1).decimals())
        );

        CallbackValidation.verifyCallback(_uniV3Factory, decoded.poolKey);

        TransferHelper.safeApprove(token0, address(_uniswapRouter), decoded.amount0);
        TransferHelper.safeApprove(token1, address(_uniswapRouter), decoded.amount1);

        uint256 amount0Owed = LowGasSafeMath.add(decoded.amount0, fee0_);
        uint256 amount1Owed = LowGasSafeMath.add(decoded.amount1, fee1_);

        address tokenA;
        address tokenB;
        uint16 feeAB;
        uint256 nextPoolIndex;
        assembly {
            nextPoolIndex := tload(0x20)
        }
        if (nextPoolIndex < _uniPools.length) {
            bytes memory nextPool = _uniPools[nextPoolIndex];
            // TODO: use this after testing correctness
            // assembly {
            //     tokenA := mload(add(nextPool, 0x20))
            //     tokenB := mload(add(nextPool, 0x40))
            //     feeAB := mload(add(nextPool, 0x60))
            // }
            (tokenA, tokenB, feeAB) = abi.decode(nextPool, (address, address, uint16));
            // call _initFlash() recursively
            IUniswapV3Pool uniPool = IUniswapV3Pool(
                PoolAddress.computeAddress(
                    _uniV3Factory, PoolAddress.PoolKey({token0: tokenA, token1: tokenB, fee: feeAB})
                )
            );
            _initFlash(
                FlashParams({
                    token0: tokenA,
                    token1: tokenB,
                    fee1: feeAB,
                    amount0: IERC20(tokenA).balanceOf(address(uniPool)) * 999 / 1000, // could test withdrawable limits further here
                    amount1: IERC20(tokenB).balanceOf(address(uniPool)) * 999 / 1000, // could test withdrawable limits further here
                    fee2: 3000,
                    fee3: 10000
                }),
                ++nextPoolIndex // next pool's index for nextPoolIndex
            );
        } else {
            // NOTE: let the games begin
            _letsPutASmileOnThatFace();
        }

        if (amount0Owed > 0) pay(token0, address(this), msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(token1, address(this), msg.sender, amount1Owed);
    }

    function _letsPutASmileOnThatFace() internal {
        console.log("let's put a smile on that face -----------------");
        for (uint256 i = 0; i < _assets.length; ++i) {
            console.log(
                IERC20Metadata(_assets[i]).symbol(),
                IERC20(_assets[i]).balanceOf(address(this)) / (10 ** IERC20Metadata(_assets[i]).decimals())
            );
        }

        // do interesting stuff here with ~$1.5B of flashloaned money
    }
}
