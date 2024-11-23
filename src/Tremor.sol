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
import {EnumerableSetLib} from "@solady/src/utils/EnumerableSetLib.sol";
import {console} from "forge-std/Test.sol";

contract Tremor is IFlashLoanReceiver, IFlashLoanRecipient, IUniswapV3FlashCallback, PeripheryPayments {
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    address internal _addressesProvider;
    IPool internal _aavePool;
    address internal _uniV3Factory;
    IVault internal _balancerVault;
    ISwapRouter internal _uniswapRouter;
    // TODO: tstore these
    EnumerableSetLib.AddressSet internal _allAssets;

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
        for (uint256 i = 0; i < aaveAssets_.length; i++) {
            _allAssets.add(aaveAssets_[i]);
        }
        for (uint256 i = 0; i < balancerAssets_.length; i++) {
            _allAssets.add(balancerAssets_[i]);
        }

        uint256[] memory interestRateModes = new uint256[](aaveAssets_.length);
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
        // approve aave pool to pull back flash loaned assets + fees
        for (uint256 i = 0; i < assets_.length; ++i) {
            IERC20(assets_[i]).approve(address(_aavePool), amounts_[i] + premiums_[i]);
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

        // initiate uniV3 flash loans
        bytes[] memory uniPools = abi.decode(userData_, (bytes[]));
        if (uniPools.length > 0) {
            // systematically storing uni pool addresses and fees in transient storage
            assembly {
                tstore(0x00, mload(uniPools))
                let offset := 0x40 // since 0x00, 0x20 stores uniPools' size and nextPoolIndex
                let uniPtr := add(add(uniPools, 0x20), mul(0x20, mload(uniPools)))
                for { let i := 0 } lt(i, mload(uniPools)) { i := add(i, 1) } {
                    uniPtr := add(uniPtr, 0x20) // skip size of uniPools[i]
                    let addr1 := mload(uniPtr)
                    let addr2 := mload(add(uniPtr, 0x20))
                    let fee := mload(add(uniPtr, 0x40))
                    uniPtr := add(uniPtr, 0x60)
                    tstore(offset, and(addr1, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
                    tstore(add(offset, 0x20), and(addr2, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
                    tstore(add(offset, 0x40), and(fee, 0xFFFF))
                    offset := add(offset, 0x60)
                }
            }

            address tokenA;
            address tokenB;
            uint16 feeAB;
            assembly {
                tokenA := tload(0x40)
                tokenB := tload(0x60)
                feeAB := tload(0x80)
            }

            // remembering new assets added
            _allAssets.add(tokenA);
            _allAssets.add(tokenB);

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

        CallbackValidation.verifyCallback(_uniV3Factory, decoded.poolKey);

        uint256 amount0Owed = LowGasSafeMath.add(decoded.amount0, fee0_);
        uint256 amount1Owed = LowGasSafeMath.add(decoded.amount1, fee1_);

        address tokenA;
        address tokenB;
        uint16 feeAB;
        uint256 uniPoolsSize;
        uint256 nextPoolIndex;
        assembly {
            uniPoolsSize := tload(0x00)
            nextPoolIndex := tload(0x20)
        }
        if (nextPoolIndex < uniPoolsSize) {
            assembly {
                tokenA := tload(add(0x40, mul(nextPoolIndex, 0x60)))
                tokenB := tload(add(0x60, mul(nextPoolIndex, 0x60)))
                feeAB := tload(add(0x80, mul(nextPoolIndex, 0x60)))
            }

            // remembering new assets added
            _allAssets.add(tokenA);
            _allAssets.add(tokenB);
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
        console.log("let's put a smile on that face ;)");
        address asset;
        for (uint256 i = 0; i < _allAssets.length(); ++i) {
            asset = _allAssets.at(i);
            console.log(
                IERC20Metadata(asset).symbol(),
                IERC20(asset).balanceOf(address(this)) / (10 ** IERC20Metadata(asset).decimals())
            );
        }

        // do interesting stuff here with your 1-block riches
    }
}
