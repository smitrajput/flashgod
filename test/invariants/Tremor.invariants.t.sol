// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {Tremor} from "../../src/Tremor.sol";
import {Handler} from "./handlers/Handler.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {Addresses} from "../../src/config/Addresses.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

contract TremorInvariants is Test {
    Tremor public tremor;
    Handler public handler;
    Addresses.EthereumAddresses internal addresses;
    IPool public pool;

    bytes32 constant ASSETS_LENGTH_SLOT = bytes32(uint256(0));
    bytes32 constant ASSETS_BASE_SLOT = bytes32(uint256(1));
    bytes32 constant ASSETS_EXISTS_BASE_SLOT = bytes32(uint256(2));
    bytes32 constant UNI_POOLS_SIZE_SLOT = bytes32(uint256(3));
    bytes32 constant NEXT_POOL_INDEX_SLOT = bytes32(uint256(4));
    bytes32 constant UNI_POOL_ADDRESS_SLOT = bytes32(uint256(5));

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        addresses = Addresses.ethereumAddresses();
        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        // Setup tremor contract
        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        // Setup handler
        handler = new Handler(tremor);

        // Target handler contract and its functions
        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = Handler.try_duplicateAssets.selector;
        selectors[1] = Handler.try_mismatchedLengths.selector;
        selectors[2] = Handler.try_negativeBalance.selector;
        selectors[3] = Handler.try_revokePermissions.selector;
        selectors[4] = Handler.try_unauthorizedCallback.selector;
        selectors[5] = Handler.try_dirtyStorage.selector;
        selectors[6] = Handler.try_multipleBreaks.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    // Asset uniqueness invariant
    function invariant_uniqueAssets() public {
        uint256 length = uint256(vm.load(address(tremor), ASSETS_LENGTH_SLOT));
        uint256 uniqueCount = 0;

        for (uint256 i = 0; i < length; i++) {
            bytes32 slot = bytes32(uint256(ASSETS_BASE_SLOT) + i);
            address asset = address(uint160(uint256(vm.load(address(tremor), slot))));

            bytes32 existsSlot = bytes32(uint256(ASSETS_EXISTS_BASE_SLOT) + uint256(uint160(asset)));
            if (uint256(vm.load(address(tremor), existsSlot)) == 1) {
                uniqueCount++;
            }
        }

        assertEq(uniqueCount, length, "Asset uniqueness violated");
    }

    // Length matching invariant
    function invariant_assetLengthMatchesExists() public {
        uint256 length = uint256(vm.load(address(tremor), ASSETS_LENGTH_SLOT));
        uint256 existsCount = 0;

        for (uint256 i = 0; i < length; i++) {
            bytes32 slot = bytes32(uint256(ASSETS_BASE_SLOT) + i);
            address asset = address(uint160(uint256(vm.load(address(tremor), slot))));

            bytes32 existsSlot = bytes32(uint256(ASSETS_EXISTS_BASE_SLOT) + uint256(uint160(asset)));
            if (uint256(vm.load(address(tremor), existsSlot)) == 1) {
                existsCount++;
            }
        }

        assertEq(length, existsCount, "Length mismatch");
    }

    // Non-negative balance invariant
    function invariant_nonNegativeBalances() public {
        uint256 length = uint256(vm.load(address(tremor), ASSETS_LENGTH_SLOT));

        for (uint256 i = 0; i < length; i++) {
            bytes32 slot = bytes32(uint256(ASSETS_BASE_SLOT) + i);
            address asset = address(uint160(uint256(vm.load(address(tremor), slot))));

            assertGe(IERC20(asset).balanceOf(address(tremor)), 0, "Negative balance detected");
        }
    }

    // Protocol permissions invariant
    function invariant_protocolPermissions() public {
        uint256 length = uint256(vm.load(address(tremor), ASSETS_LENGTH_SLOT));

        for (uint256 i = 0; i < length; i++) {
            bytes32 slot = bytes32(uint256(ASSETS_BASE_SLOT) + i);
            address asset = address(uint160(uint256(vm.load(address(tremor), slot))));

            assertGe(
                IERC20(asset).allowance(address(tremor), address(pool)),
                type(uint256).max,
                "Invalid protocol permissions"
            );
        }
    }

    // Transient storage cleanup invariant
    function invariant_cleanTransientStorage() public {
        assertEq(
            uint256(vm.load(address(tremor), bytes32(uint256(UNI_POOLS_SIZE_SLOT)))), 0, "Dirty UNI_POOLS_SIZE_SLOT"
        );

        assertEq(
            uint256(vm.load(address(tremor), bytes32(uint256(NEXT_POOL_INDEX_SLOT)))), 0, "Dirty NEXT_POOL_INDEX_SLOT"
        );

        assertEq(
            uint256(vm.load(address(tremor), bytes32(uint256(UNI_POOL_ADDRESS_SLOT)))), 0, "Dirty UNI_POOL_ADDRESS_SLOT"
        );

        uint256 length = uint256(vm.load(address(tremor), ASSETS_LENGTH_SLOT));
        assertEq(length, 0, "Dirty ASSETS_LENGTH_SLOT");
    }

    // Callback security invariant
    function invariant_callbackSecurity() public {
        vm.expectRevert(Tremor.NotAavePool.selector);
        tremor.executeOperation(new address[](0), new uint256[](0), new uint256[](0), address(0), "");

        vm.expectRevert(Tremor.NotBalancerVault.selector);
        tremor.receiveFlashLoan(new IERC20[](0), new uint256[](0), new uint256[](0), "");

        vm.expectRevert(Tremor.NotUniPool.selector);
        tremor.uniswapV3FlashCallback(0, 0, "");
    }
}
