// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {Tremor} from "../../../src/Tremor.sol";
import {Addresses} from "../../../src/config/Addresses.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";

contract Handler is Test {
    Tremor public tremor;
    Addresses.EthereumAddresses internal addresses;
    IPool public pool;

    constructor(Tremor _tremor) {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        tremor = _tremor;
        addresses = Addresses.ethereumAddresses();
        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());
    }

    // Try to break asset uniqueness invariant
    function try_duplicateAssets(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 100 ether);

        // Create arrays with duplicate assets
        address[] memory assets = new address[](2);
        assets[0] = addresses.WETH;
        assets[1] = addresses.WETH; // Duplicate WETH

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        tremor.dominoeFlashLoans(assets, amounts, new IERC20[](0), new uint256[](0), new bytes[](0));
    }

    // Try to break length matching invariant
    function try_mismatchedLengths(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 100 ether);

        address[] memory assets = new address[](2);
        assets[0] = addresses.WETH;
        assets[1] = addresses.USDC;

        uint256[] memory amounts = new uint256[](1); // Mismatched length
        amounts[0] = amount;

        vm.expectRevert(Tremor.LengthMismatchAave.selector);
        tremor.dominoeFlashLoans(assets, amounts, new IERC20[](0), new uint256[](0), new bytes[](0));
    }

    // Try to break non-negative balance invariant
    function try_negativeBalance(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 100 ether);

        address[] memory assets = new address[](1);
        assets[0] = addresses.WETH;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // Try to transfer out more than borrowed
        vm.prank(address(tremor));
        IERC20(addresses.WETH).transfer(address(this), amount + 1);

        tremor.dominoeFlashLoans(assets, amounts, new IERC20[](0), new uint256[](0), new bytes[](0));
    }

    // Try to break protocol permissions invariant
    function try_revokePermissions() public {
        // Try to revoke approvals
        vm.prank(address(tremor));
        IERC20(addresses.WETH).approve(address(pool), 0);

        address[] memory assets = new address[](1);
        assets[0] = addresses.WETH;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        tremor.dominoeFlashLoans(assets, amounts, new IERC20[](0), new uint256[](0), new bytes[](0));
    }

    // Try to break callback security
    function try_unauthorizedCallback() public {
        // Try unauthorized callbacks
        vm.prank(address(this));
        vm.expectRevert(Tremor.NotAavePool.selector);
        tremor.executeOperation(new address[](0), new uint256[](0), new uint256[](0), address(0), "");
    }

    // Try to break transient storage cleanup
    function try_dirtyStorage(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 100 ether);

        address[] memory assets = new address[](1);
        assets[0] = addresses.WETH;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // Force revert mid-operation to leave dirty storage
        vm.mockCallRevert(address(pool), abi.encodeWithSelector(IPool.flashLoan.selector), "FORCED_REVERT");

        vm.expectRevert("FORCED_REVERT");
        tremor.dominoeFlashLoans(assets, amounts, new IERC20[](0), new uint256[](0), new bytes[](0));
    }

    // Try to break multiple invariants at once
    function try_multipleBreaks(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 100 ether);

        // Duplicate assets
        address[] memory assets = new address[](2);
        assets[0] = addresses.WETH;
        assets[1] = addresses.WETH;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        // Revoke permissions
        vm.prank(address(tremor));
        IERC20(addresses.WETH).approve(address(pool), 0);

        tremor.dominoeFlashLoans(assets, amounts, new IERC20[](0), new uint256[](0), new bytes[](0));
    }
}
