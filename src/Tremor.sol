// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IPoolAddressesProvider, IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IFlashLoanReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
// IERC20 already imported in PeripheryPayments
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";
import "@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol";
import "@uniswap/v3-periphery/contracts/base/PeripheryImmutableState.sol";
import "@uniswap/v3-periphery/contracts/libraries/CallbackValidation.sol";

import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IFlashLoanRecipient} from "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import {IERC20 as IERC20_BAL} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {console} from "forge-std/Test.sol";

/// @title Tremor
/// @author smitrajput: https://x.com/smit__rajput
/// @notice Aggregated flash loans on Aave, Balancer and Uniswap V3 on 7 sizemic evm-compatible chains
/// @dev dominoeFlashLoans() is the only intended entry point for you
contract Tremor is IFlashLoanReceiver, IFlashLoanRecipient, IUniswapV3FlashCallback, PeripheryPayments {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Type Declarations                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct FlashParams {
        address token0;
        uint24 fee1;
        uint24 fee2;
        uint24 fee3;
        address token1;
        uint256 amount0;
        uint256 amount1;
    }

    /// fee2 and fee3 are the two other fees associated with the two other pools of token0 and token1
    struct FlashCallbackData {
        uint256 amount0;
        uint256 amount1;
        address payer;
        uint24 poolFee2;
        uint24 poolFee3;
        PoolAddress.PoolKey poolKey;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Constants                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 constant AAVE_POOL_SLOT = 0xA77AC4ED; // Slot to store Aave pool address
    uint256 constant UNI_V3_FACTORY_SLOT = 0xABADD00D; // Slot to store UniV3 factory address
    uint256 constant BALANCER_VAULT_SLOT = 0xAC1DBED; // Slot to store Balancer vault address
    /// first 4 slots are sufficiently spaced out to avoid collisions
    uint256 constant ASSETS_BASE_SLOT = 0xADD1C7ED; // Base slot for our array of assets
    uint256 constant ASSETS_LENGTH_SLOT = 0xBADBABE; // Slot to store length
    uint256 constant ASSETS_EXISTS_BASE_SLOT = 0xCA05C0DE; // Base slot for existence mapping
    uint256 constant UNI_POOLS_SIZE_SLOT = 0xD15EA5ED; // Slot to store uniPools' size
    uint256 constant UNI_POOL_ADDRESS_SLOT = 0xDEFEA7ED; // Slot to store uniPool's address
    uint256 constant NEXT_POOL_INDEX_SLOT = 0xDEADFACE; // Slot to store next pool index

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Storage Variables                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /////////////////////////// ;) /////////////////////////////////

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Events                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Errors                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error LengthMismatchAave();
    error LengthMismatchBalancer();
    error NotAavePool();
    error NotBalancerVault();
    error NotUniPool();

    constructor(address uniV3Factory_, address WETH_) PeripheryImmutableState(uniV3Factory_, WETH_) {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         External Functions                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Initiates the flash loans killchain on Aave, Balancer and Uniswap V3
    /// @dev callback from aave flash loan calls balancer flash loan, whose callback
    /// initiates the uniswap flash loans
    /// @param aaveAssets_ Array of Aave assets to flash loan
    /// @param aaveAmounts_ Array of Aave assets' amounts to flash loan
    /// @param balancerAssets_ Array of Balancer assets to flash loan
    /// @param balancerAmounts_ Array of Balancer assets' amounts to flash loan
    /// @param uniPools_ Array of bytes encoding Uniswap V3 pools' details to flash loan
    function dominoeFlashLoans(
        bytes calldata providers_,
        address[] calldata aaveAssets_,
        uint256[] calldata aaveAmounts_,
        IERC20_BAL[] calldata balancerAssets_,
        uint256[] calldata balancerAmounts_,
        bytes[] calldata uniPools_
    ) external {
        if (aaveAssets_.length != aaveAmounts_.length) revert LengthMismatchAave();
        if (balancerAssets_.length != balancerAmounts_.length) revert LengthMismatchBalancer();

        _tstoreProviders(providers_);

        _addToAssetSet(aaveAssets_);
        // need to call single asset variant coz of IERC20_BAL type for each balancer asset
        for (uint256 i = 0; i < balancerAssets_.length; ++i) {
            _addToAssetSet(address(balancerAssets_[i]));
        }

        address aavePool;
        assembly ("memory-safe") {
            aavePool := tload(AAVE_POOL_SLOT)
        }
        IPool(aavePool).flashLoan(
            address(this),
            aaveAssets_,
            aaveAmounts_,
            new uint256[](aaveAssets_.length), // interest rate modes = 0 for all assets
            address(0),
            abi.encode(balancerAssets_, balancerAmounts_, uniPools_),
            0
        );

        emit DominoeFlashLoansInitiated(aaveAssets_, aaveAmounts_, balancerAssets_, balancerAmounts_, uniPools_.length);
    }

    /*              ║
         *          ║
         *          ║                     +------------------+
         *          ▼                     |                  |
         *          ║                     |    Aave Pool     |
         *          ║                     |                  |
         *          ║                     +-----------------+
         *          ║                              ║
         *          ╚==============================╝
         *                   flashLoan()           ║
         *                                         ║ callback()
         *                                         ║
         *                                         ║
         *                                         ║
         *                                         ▼
         */

    /// @dev callback by aave's pool contract post sending flash loan
    /// @param assets_ Array of Aave assets in flash loan
    /// @param amounts_ Array of Aave assets' amounts in flash loan
    /// @param premiums_ Array of Aave assets' fees to be paid in flash loan
    /// @param initiator_ Address of the initiator of the flash loan, i.e. this contract
    /// @param params_ Encoded data from dominoeFlashLoans()
    /// @return true or false if flash-loan returned successfully with fees or not
    function executeOperation(
        address[] calldata assets_,
        uint256[] calldata amounts_,
        uint256[] calldata premiums_,
        address initiator_,
        bytes calldata params_
    ) external returns (bool) {
        address aavePool;
        address balancerVault;
        assembly ("memory-safe") {
            aavePool := tload(AAVE_POOL_SLOT)
            balancerVault := tload(BALANCER_VAULT_SLOT)
        }

        if (msg.sender != aavePool) revert NotAavePool();

        // approve aave pool to pull back flash loaned assets + fees
        for (uint256 i = 0; i < assets_.length; ++i) {
            IERC20(assets_[i]).approve(address(aavePool), amounts_[i] + premiums_[i]);
        }

        (IERC20_BAL[] memory balancerAssets, uint256[] memory balancerAmounts, bytes[] memory uniPools) =
            abi.decode(params_, (IERC20_BAL[], uint256[], bytes[]));
        // call balancer flash loan and from its callback, call uniswap flash loans
        // NOTE: calling _balancerVault.flashLoan() despite balancerAssets.length == 0 since
        // uni flash loan depends on its callback
        IVault(balancerVault).flashLoan(this, balancerAssets, balancerAmounts, abi.encode(uniPools));

        emit AaveFlashLoanExecuted(assets_, amounts_, premiums_, initiator_);

        return true;
    }

    /*              ║
         *          ║
         *          ║                     +------------------+
         *          ▼                     |                  |
         *          ║                     |  Balancer Vault  |
         *          ║                     |                  |
         *          ║                     +-----------------+
         *          ║                              ║
         *          ╚==============================╝
         *                   flashLoan()           ║
         *                                         ║ callback()
         *                                         ║
         *                                         ║
         *                                         ║
         *                                         ▼
         */

    /// @dev callback by balancer's vault contract post sending flash loan
    /// @param tokens_ Array of Balancer assets in flash loan
    /// @param amounts_ Array of Balancer assets' amounts in flash loan
    /// @param feeAmounts_ Array of Balancer assets' fees to be paid in flash loan
    /// @param userData_ Encoded data from executeOperation()
    function receiveFlashLoan(
        IERC20_BAL[] memory tokens_,
        uint256[] memory amounts_,
        uint256[] memory feeAmounts_,
        bytes memory userData_
    ) external override {
        address balancerVault;
        assembly ("memory-safe") {
            balancerVault := tload(BALANCER_VAULT_SLOT)
        }
        if (msg.sender != balancerVault) revert NotBalancerVault();

        // initiate uniV3 flash loans
        bytes[] memory uniPools = abi.decode(userData_, (bytes[]));
        if (uniPools.length > 0) {
            address tokenA;
            address tokenB;
            uint16 feeAB;
            uint256 amountA;
            uint256 amountB;
            // linearly storing uni pool addresses and fees in transient storage slots 0x00, 0x01, 0x02, ...
            assembly ("memory-safe") {
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
            TransferHelper.safeTransfer(address(tokens_[i]), address(balancerVault), amounts_[i] + feeAmounts_[i]);
        }

        emit BalancerFlashLoanReceived(tokens_, amounts_, feeAmounts_);
    }

    /*              ║                                                ▲
         *          ║                                                ║
         *          ║                     +------------------+       ║
         *          ▼                     |                  |       ║
         *          ║                     |  Uniswap V3 Pool |       ║
         *          ║                     |       (i)        |       ║
         *          ║                     +-----------------+        ║
         *          ║                              ║                 ║
         *          ╚==============================╝                 ║
         *                   flashLoan()           ║                 ║
         *                                         ║ callback()      ║
         *                                         ║                 ║
         *                                         ║                 ║
         *                                         ║                 ║
         *                                         ▼                 ║
         */

    /// @dev callback by uniswapV3Pool contract post sending flash loan
    /// @param fee0_ Uniswap V3 pool's token0 fee
    /// @param fee1_ Uniswap V3 pool's token1 fee
    /// @param data_ Encoded data from UniswapV3Pool.flash()
    function uniswapV3FlashCallback(uint256 fee0_, uint256 fee1_, bytes calldata data_) external override {
        address uniPoolAddress;
        assembly ("memory-safe") {
            uniPoolAddress := tload(UNI_POOL_ADDRESS_SLOT)
        }
        if (msg.sender != uniPoolAddress) revert NotUniPool();

        FlashCallbackData memory decoded = abi.decode(data_, (FlashCallbackData));
        address token0 = decoded.poolKey.token0;
        address token1 = decoded.poolKey.token1;

        // factory being accessed from PeripheryImmutableState
        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        uint256 amount0Owed = LowGasSafeMath.add(decoded.amount0, fee0_);
        uint256 amount1Owed = LowGasSafeMath.add(decoded.amount1, fee1_);

        address tokenA;
        address tokenB;
        uint16 feeAB;
        uint256 amountA;
        uint256 amountB;
        uint256 uniPoolsSize;
        uint256 nextPoolIndex;
        assembly ("memory-safe") {
            uniPoolsSize := tload(UNI_POOLS_SIZE_SLOT)
            nextPoolIndex := tload(NEXT_POOL_INDEX_SLOT)
        }
        if (nextPoolIndex < uniPoolsSize) {
            assembly ("memory-safe") {
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

        if (amount0Owed > 0) {
            pay(token0, address(this), msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            pay(token1, address(this), msg.sender, amount1Owed);
        }

        emit UniswapFlashLoanCallback(token0, token1, amount0Owed, amount1Owed, nextPoolIndex);
    }

    /// @dev dummy implementation to satisfy IFlashLoanReceiver interface
    function ADDRESSES_PROVIDER() external pure override returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(address(0));
    }

    /// @dev dummy implementation to satisfy IFlashLoanReceiver interface
    function POOL() external pure override returns (IPool) {
        return IPool(address(0));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Internal Functions                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev helper function to initiate uniswap flash loan
    /// @param params_ Encoded data from receiveFlashLoan(), uniswapV3FlashCallback()
    /// @param nextPoolIndex_ Next pool's index to withdraw flash loanfrom
    function _initFlash(FlashParams memory params_, uint256 nextPoolIndex_) internal {
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params_.token0, token1: params_.token1, fee: params_.fee1});
        IUniswapV3Pool uniPool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));

        address uniPoolAddress = address(uniPool);
        assembly ("memory-safe") {
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

    /// @dev FINAL trigger function to execute your logic with the flash loaned funds
    /// @dev Currently just logs the balances of all flash loaned assets in the Iterable-Set
    function _letsPutASmileOnThatFace() internal {
        console.log("let's put a smile on that face ;)");

        uint256 length;
        address asset;
        assembly ("memory-safe") {
            length := tload(ASSETS_LENGTH_SLOT)
        }

        // Iterate through the array portion where we stored the assets sequentially
        for (uint256 i = 0; i < length; ++i) {
            assembly ("memory-safe") {
                asset := tload(add(ASSETS_BASE_SLOT, i))
            }
            uint256 balance = IERC20(asset).balanceOf(address(this));
            string memory symbol = IERC20Metadata(asset).symbol();

            emit TremorBalances(asset, symbol, balance);

            console.log(symbol, balance / (10 ** IERC20Metadata(asset).decimals()));
        }

        ////////////////////////////////////////////////////////////////////////
        ///                                                                  ///
        ///~~~~~~~ DO INTERESTING STUFF HERE WITH YOUR 1-BLOCK RICHES ~~~~~~~///
        ///                                                                  ///
        ///                                                                  ///
        ///                         /\    /\                                 ///
        ///                      /\/$$$  /$$$\                               ///
        ///                    /$$$$$$$\/$$$$$\                              ///
        ///                   /$$$$$$$$$$$$$$$$$\                            ///
        ///                  /$$$$_____$$$_____$$$\                          ///
        ///                 /$$$$/     $$$     \$$$$\                        ///
        ///                /$$$$/ (HA) $$$ (HA) \$$$$\                       ///
        ///               /$$$$/       $$$       \$$$$\                      ///
        ///              /$$$$         $$$         $$$$\                     ///
        ///             /$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\                    ///
        ///            /$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\                   ///
        ///           /$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\                 ///
        ///      it's not about money, it's about sending a message          ///
        ///                                                                  ///
        ////////////////////////////////////////////////////////////////////////
    }

    /// @dev helper function to store flashloan providers in transient storage slots
    /// @param providers_ Encoded providers' data from dominoeFlashLoans()
    function _tstoreProviders(bytes calldata providers_) internal {
        (address aavePool, address balancerVault) = abi.decode(providers_, (address, address));
        assembly ("memory-safe") {
            tstore(AAVE_POOL_SLOT, aavePool)
            tstore(BALANCER_VAULT_SLOT, balancerVault)
        }
    }

    /// @dev an Iterable-Set implementation for storing unique assets in O(1) time
    /// with a separate array-like structure for iterating over assets in O(n) time
    /// @param asset_ Address of the asset to add to the Iterable-Set
    function _addToAssetSet(address asset_) internal {
        bool added;
        uint256 newLength;
        assembly ("memory-safe") {
            // Check if asset already exists using the asset address as key
            let exists := tload(add(ASSETS_EXISTS_BASE_SLOT, asset_))

            // If it doesn't exist, add it
            if iszero(exists) {
                added := true
                // Mark as existing
                tstore(add(ASSETS_EXISTS_BASE_SLOT, asset_), 1)

                // Add to array
                let currentLength := tload(ASSETS_LENGTH_SLOT)
                tstore(add(ASSETS_BASE_SLOT, currentLength), asset_)
                // Increment length
                newLength := add(currentLength, 1)
                tstore(ASSETS_LENGTH_SLOT, newLength)
            }
        }

        if (added) {
            emit AssetAdded(asset_, newLength);
        }
    }

    /// @dev convenience overloader for cutting off JUMPs in adding aave assets
    /// @param assets_ Array of addresses of assets to add to the Iterable-Set
    function _addToAssetSet(address[] memory assets_) internal {
        address asset;
        bool added;
        uint256 newLength;
        for (uint256 i = 0; i < assets_.length; ++i) {
            asset = assets_[i];
            added = false;
            assembly ("memory-safe") {
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

    /// @dev helper function to clean up transient storage slots after flash
    /// loan txn for security
    function _cleanTstoreSlots() internal {
        assembly ("memory-safe") {
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
