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

    uint256 constant ASSETS_BASE_SLOT = 0xADD1C7ED; // Base slot for our array of assets = 1 billy
    uint256 constant ASSETS_LENGTH_SLOT = 0xBADBABE; // Slot to store length = 2 billy
    uint256 constant ASSETS_EXISTS_BASE_SLOT = 0xCA05C0DE; // Base slot for existence mapping = 3 billy
    uint256 constant UNI_POOLS_SIZE_SLOT = 0xD15EA5ED; // Slot to store uniPools' size = 3.254 billy
    uint256 constant UNI_POOL_ADDRESS_SLOT = 0xDEFEA7ED; // Slot to store uniPool's address
    uint256 constant NEXT_POOL_INDEX_SLOT = 0xDEADFACE; // Slot to store next pool index = 3.735 billy

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

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Handler.try_duplicateAssets.selector;
        selectors[1] = Handler.try_breakingApprovals.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    // Asset uniqueness in HashSet invariant
    // NOTE: assumption here is that this function is called in the same txn as the test run txn, to
    // be able to access the same transaction storage slots
    function invariant_uniqueAssets() public {
        // uint256 length = uint256(vm.load(address(tremor), ASSETS_LENGTH_SLOT));
        uint256 length;
        address asset;
        uint256 exists;
        uint256 uniqueCount;
        assembly {
            length := tload(ASSETS_LENGTH_SLOT)
        }
        for (uint256 i = 0; i < length; i++) {
            assembly {
                asset := tload(add(ASSETS_BASE_SLOT, i))
                exists := tload(add(ASSETS_EXISTS_BASE_SLOT, asset))

                if eq(exists, 1) { uniqueCount := add(uniqueCount, 1) }
            }
        }

        assertEq(uniqueCount, length, "Asset uniqueness violated");
    }

    // Approvals safety invariant
    function invariant_approvalsSafety() public {
        assertEq(IERC20(addresses.WETH).allowance(address(tremor), address(pool)), 0, "Inconsistent approvals");
    }

    // All flash loans should be repaid (no outstanding debt)
    function invariant_noOutstandingDebt() public {
        (uint256 totalCollateralBase, uint256 totalDebtBase,,,,) = pool.getUserAccountData(address(tremor));
        assertEq(totalDebtBase, 0, "Outstanding debt");
    }
}
