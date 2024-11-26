// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IPoolAddressesProvider, IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IFlashLoanSimpleReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IFlashLoanReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
// IERC20 already imported in PeripheryPayments
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

    uint256 constant ASSETS_BASE_SLOT = 0x3B9ACA00; // Base slot for our array of assets = 1 billy
    uint256 constant ASSETS_LENGTH_SLOT = 0x77359400; // Slot to store length = 2 billy
    uint256 constant ASSETS_EXISTS_BASE_SLOT = 0xB2D05E00; // Base slot for existence mapping = 3 billy
    uint256 constant UNI_POOLS_SIZE_SLOT = 0xC0FFEEBABE; // Slot to store uniPools' size = 3.254 billy
    uint256 constant UNI_POOL_ADDRESS_SLOT = 0xDEADFACE; // Slot to store uniPool's address
    uint256 constant NEXT_POOL_INDEX_SLOT = 0xDEADBEEF; // Slot to store next pool index = 3.735 billy

    address internal _addressesProvider;
    IPool internal _aavePool;
    address internal _uniV3Factory;
    ISwapRouter internal _uniswapRouter;
    IVault internal _balancerVault;

    event DominoeFlashLoansInitiated(
        address[] aaveAssets,
        uint256[] aaveAmounts,
        IERC20_BAL[] balancerAssets,
        uint256[] balancerAmounts,
        uint256 uniPoolsCount
    );
    event AaveFlashLoanExecuted(address[] assets, uint256[] amounts, uint256[] premiums, address initiator);
    event BalancerFlashLoanReceived(IERC20_BAL[] tokens, uint256[] amounts, uint256[] feeAmounts);
    event UniswapFlashLoanInitiated(
        address token0, address token1, uint24 fee, uint256 amount0, uint256 amount1, uint256 poolIndex
    );
    event UniswapFlashLoanCallback(
        address token0, address token1, uint256 amount0Owed, uint256 amount1Owed, uint256 nextPoolIndex
    );
    event AssetAdded(address asset, uint256 newLength);
    event TremorBalances(address asset, string symbol, uint256 balance);

    error LengthMismatchAave();
    error LengthMismatchBalancer();
    error NotAavePool();
    error NotBalancerVault();
    error NotUniPool();

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
        IERC20_BAL[] calldata balancerAssets_,
        uint256[] calldata balancerAmounts_,
        bytes[] calldata uniPools_
    ) external {
        if (aaveAssets_.length != aaveAmounts_.length) revert LengthMismatchAave();
        if (balancerAssets_.length != balancerAmounts_.length) revert LengthMismatchBalancer();

        _addToAssetSet(aaveAssets_);
        // need to call single asset variant coz of IERC20_BAL type for each balancer asset
        for (uint256 i = 0; i < balancerAssets_.length; ++i) {
            _addToAssetSet(address(balancerAssets_[i]));
        }

        uint256[] memory interestRateModes = new uint256[](aaveAssets_.length);
        _aavePool.flashLoan(
            address(this),
            aaveAssets_,
            aaveAmounts_,
            interestRateModes,
            address(0),
            abi.encode(balancerAssets_, balancerAmounts_, uniPools_),
            0
        );

        emit DominoeFlashLoansInitiated(aaveAssets_, aaveAmounts_, balancerAssets_, balancerAmounts_, uniPools_.length);
    }

    /// @dev aave flash-loan callback
    function executeOperation(
        address[] calldata assets_,
        uint256[] calldata amounts_,
        uint256[] calldata premiums_,
        address initiator_,
        bytes calldata params_
    ) external returns (bool) {
        if (msg.sender != address(_aavePool)) revert NotAavePool();

        // approve aave pool to pull back flash loaned assets + fees
        for (uint256 i = 0; i < assets_.length; ++i) {
            IERC20(assets_[i]).approve(address(_aavePool), amounts_[i] + premiums_[i]);
        }

        (IERC20_BAL[] memory balancerAssets, uint256[] memory balancerAmounts, bytes[] memory uniPools) =
            abi.decode(params_, (IERC20_BAL[], uint256[], bytes[]));
        // call balancer flash loan and from its callback, call uniswap flash loans
        // NOTE: calling _balancerVault.flashLoan() despite balancerAssets.length == 0 since
        // uni flash loan depends on its callback
        _balancerVault.flashLoan(this, balancerAssets, balancerAmounts, abi.encode(uniPools));

        emit AaveFlashLoanExecuted(assets_, amounts_, premiums_, initiator_);

        return true;
    }

    /// @dev balancer flash-loan callback
    function receiveFlashLoan(
        IERC20_BAL[] memory tokens_,
        uint256[] memory amounts_,
        uint256[] memory feeAmounts_,
        bytes memory userData_
    ) external override {
        if (msg.sender != address(_balancerVault)) revert NotBalancerVault();

        // initiate uniV3 flash loans
        bytes[] memory uniPools = abi.decode(userData_, (bytes[]));
        if (uniPools.length > 0) {
            address tokenA;
            address tokenB;
            uint16 feeAB;
            uint256 amountA;
            uint256 amountB;
            // linearly storing uni pool addresses and fees in transient storage slots 0x00, 0x01, 0x02, ...
            assembly {
                let offset
                let uniPtr
                tstore(UNI_POOLS_SIZE_SLOT, mload(uniPools))
                // simple slot to start storing uni pool addresses and fees at
                offset := 0x00
                // skipping dynamic array's size + number of headers (= uniPools[] size) which are added by compiler
                // during encoding a dynamic array of dynamic arrays (uniPools).
                // shl(5, mload(uniPools)) == mul(mload(uniPools), 0x20)
                // then add 0x20 to skip size of uniPools[0]
                uniPtr := add(add(add(uniPools, 0x20), shl(5, mload(uniPools))), 0x20)

                // i = 0 done here to avoid its tstore + tload coz tokenA/tokenB/... for i = 0 are
                // used right after, in the call to _initFlash()
                tokenA := mload(uniPtr)
                tokenB := mload(add(uniPtr, 0x20))
                feeAB := mload(add(uniPtr, 0x40))
                amountA := mload(add(uniPtr, 0x60))
                amountB := mload(add(uniPtr, 0x80))
                // skip 5 elements + size of uniPools[i]
                uniPtr := add(uniPtr, 0xC0)
                // increment offset by 5
                offset := add(offset, 0x05)

                // note i = 1
                for { let i := 1 } iszero(eq(i, mload(uniPools))) { i := add(i, 1) } {
                    tstore(offset, mload(uniPtr))
                    tstore(add(offset, 0x01), mload(add(uniPtr, 0x20)))
                    tstore(add(offset, 0x02), mload(add(uniPtr, 0x40)))
                    tstore(add(offset, 0x03), mload(add(uniPtr, 0x60)))
                    tstore(add(offset, 0x04), mload(add(uniPtr, 0x80)))

                    // skip 5 elements + size of uniPools[i]
                    uniPtr := add(uniPtr, 0xC0)
                    // increment offset by 5
                    offset := add(offset, 0x05)
                }
            }

            // remembering new assets added
            _addToAssetSet(tokenA);
            _addToAssetSet(tokenB);

            _initFlash(
                FlashParams({
                    token0: tokenA,
                    token1: tokenB,
                    fee1: feeAB,
                    amount0: amountA,
                    amount1: amountB,
                    fee2: 3000,
                    fee3: 10000
                }),
                1
            );
        }

        // return loan to balancer vault
        for (uint256 i = 0; i < tokens_.length; ++i) {
            TransferHelper.safeTransfer(address(tokens_[i]), address(_balancerVault), amounts_[i] + feeAmounts_[i]);
        }

        emit BalancerFlashLoanReceived(tokens_, amounts_, feeAmounts_);
    }

    function uniswapV3FlashCallback(uint256 fee0_, uint256 fee1_, bytes calldata data_) external override {
        address uniPoolAddress;
        assembly {
            uniPoolAddress := tload(UNI_POOL_ADDRESS_SLOT)
        }
        if (msg.sender != uniPoolAddress) revert NotUniPool();

        FlashCallbackData memory decoded = abi.decode(data_, (FlashCallbackData));
        address token0 = decoded.poolKey.token0;
        address token1 = decoded.poolKey.token1;

        CallbackValidation.verifyCallback(_uniV3Factory, decoded.poolKey);

        uint256 amount0Owed = LowGasSafeMath.add(decoded.amount0, fee0_);
        uint256 amount1Owed = LowGasSafeMath.add(decoded.amount1, fee1_);

        address tokenA;
        address tokenB;
        uint16 feeAB;
        uint256 amountA;
        uint256 amountB;
        uint256 uniPoolsSize;
        uint256 nextPoolIndex;
        assembly {
            uniPoolsSize := tload(UNI_POOLS_SIZE_SLOT)
            nextPoolIndex := tload(NEXT_POOL_INDEX_SLOT)
        }
        if (nextPoolIndex < uniPoolsSize) {
            assembly {
                // NOTE: caching consumes more gas than recomputing everytime
                // let nextPoolPos := mul(nextPoolIndex, 0x05)
                tokenA := tload(add(0x00, mul(nextPoolIndex, 0x05)))
                tokenB := tload(add(0x01, mul(nextPoolIndex, 0x05)))
                feeAB := tload(add(0x02, mul(nextPoolIndex, 0x05)))
                amountA := tload(add(0x03, mul(nextPoolIndex, 0x05)))
                amountB := tload(add(0x04, mul(nextPoolIndex, 0x05)))
            }

            // remembering new assets added
            _addToAssetSet(tokenA);
            _addToAssetSet(tokenB);

            _initFlash(
                FlashParams({
                    token0: tokenA,
                    token1: tokenB,
                    fee1: feeAB,
                    amount0: amountA,
                    amount1: amountB,
                    fee2: 3000,
                    fee3: 10000
                }),
                ++nextPoolIndex // next pool's index for nextPoolIndex
            );
        } else {
            // NOTE: WHY SO SERIOUS?
            _letsPutASmileOnThatFace();

            _cleanTstoreSlots();
        }

        if (amount0Owed > 0) pay(token0, address(this), msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(token1, address(this), msg.sender, amount1Owed);

        emit UniswapFlashLoanCallback(token0, token1, amount0Owed, amount1Owed, nextPoolIndex);
    }

    function _initFlash(FlashParams memory params_, uint256 nextPoolIndex_) internal {
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params_.token0, token1: params_.token1, fee: params_.fee1});
        IUniswapV3Pool uniPool = IUniswapV3Pool(PoolAddress.computeAddress(_uniV3Factory, poolKey));

        address uniPoolAddress = address(uniPool);
        assembly {
            tstore(UNI_POOL_ADDRESS_SLOT, uniPoolAddress)
            tstore(NEXT_POOL_INDEX_SLOT, nextPoolIndex_)
        }

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

        emit UniswapFlashLoanInitiated(
            params_.token0, params_.token1, params_.fee1, params_.amount0, params_.amount1, nextPoolIndex_
        );
    }

    function _letsPutASmileOnThatFace() internal {
        console.log("let's put a smile on that face ;)");

        uint256 length;
        address asset;
        assembly {
            length := tload(ASSETS_LENGTH_SLOT)
        }

        // Iterate through the array portion where we stored the assets sequentially
        for (uint256 i = 0; i < length; ++i) {
            assembly {
                asset := tload(add(ASSETS_BASE_SLOT, i))
            }
            uint256 balance = IERC20(asset).balanceOf(address(this));
            string memory symbol = IERC20Metadata(asset).symbol();

            emit TremorBalances(asset, symbol, balance);

            console.log(symbol, balance / (10 ** IERC20Metadata(asset).decimals()));
        }

        ////////////////////////////////////////////////////////////////////////
        ///~~~~~~~ do interesting stuff here with your 1-block riches ~~~~~~~///
        ////////////////////////////////////////////////////////////////////////
    }

    /// @dev a HashSet implementation for storing unique assets in O(1) time
    /// with a separate iteratable array-like structure for accessing assets in O(1) time
    function _addToAssetSet(address asset) internal {
        bool added;
        uint256 newLength;
        assembly {
            // Check if asset already exists using the asset address as key
            let exists := tload(add(ASSETS_EXISTS_BASE_SLOT, asset))

            // If it doesn't exist, add it
            if iszero(exists) {
                added := true
                // Mark as existing
                tstore(add(ASSETS_EXISTS_BASE_SLOT, asset), 1)

                // Add to array
                let currentLength := tload(ASSETS_LENGTH_SLOT)
                tstore(add(ASSETS_BASE_SLOT, currentLength), asset)
                // Increment length
                newLength := add(currentLength, 1)
                tstore(ASSETS_LENGTH_SLOT, newLength)
            }
        }

        if (added) {
            emit AssetAdded(asset, newLength);
        }
    }

    /// @dev convenience overloader for cutting off JUMPs in adding aave assets
    function _addToAssetSet(address[] memory assets) internal {
        address asset;
        bool added;
        uint256 newLength;
        for (uint256 i = 0; i < assets.length; ++i) {
            asset = assets[i];
            added = false;
            assembly {
                // Check if asset already exists using the asset address as key
                let exists := tload(add(ASSETS_EXISTS_BASE_SLOT, asset))

                // If it doesn't exist, add it
                if iszero(exists) {
                    added := true
                    // Mark as existing
                    tstore(add(ASSETS_EXISTS_BASE_SLOT, asset), 1)

                    // Add to array
                    let currentLength := tload(ASSETS_LENGTH_SLOT)
                    tstore(add(ASSETS_BASE_SLOT, currentLength), asset)
                    // Increment length
                    newLength := add(currentLength, 1)
                    tstore(ASSETS_LENGTH_SLOT, newLength)
                }
            }

            if (added) {
                emit AssetAdded(asset, newLength);
            }
        }
    }

    function _cleanTstoreSlots() internal {
        assembly {
            for { let i := 0 } lt(i, tload(UNI_POOLS_SIZE_SLOT)) { i := add(i, 1) } {
                tstore(add(0x00, mul(i, 0x03)), 0)
                tstore(add(0x01, mul(i, 0x03)), 0)
                tstore(add(0x02, mul(i, 0x03)), 0)
            }
            tstore(UNI_POOLS_SIZE_SLOT, 0)
            tstore(NEXT_POOL_INDEX_SLOT, 0)

            // clear assets
            for { let i := 0 } lt(i, tload(ASSETS_LENGTH_SLOT)) { i := add(i, 1) } {
                tstore(add(ASSETS_EXISTS_BASE_SLOT, tload(add(ASSETS_BASE_SLOT, i))), 0)
                tstore(add(ASSETS_BASE_SLOT, i), 0)
            }
            tstore(ASSETS_LENGTH_SLOT, 0)
        }
    }
}
