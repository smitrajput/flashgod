// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {Tremor} from "../../../src/Tremor.sol";
import {Addresses} from "../../../src/config/Addresses.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract Handler is Test {
    Tremor public tremor;
    Addresses.EthereumAddresses internal addresses;
    IPool public pool;

    constructor(Tremor _tremor) {
        // vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        tremor = _tremor;
        addresses = Addresses.ethereumAddresses();
        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());
    }

    function simulateAaveAndUniswapFlashLoanFees(
        address[] memory assets,
        uint256[] memory amounts,
        uint256 aavePremium,
        address uniV3Factory,
        bytes[] memory uniPools
    ) internal {
        // simulating aave flash-loan fees, which should come from flash-loan profits
        for (uint256 i = 0; i < amounts.length; i++) {
            // NOTE: aavePremium is 500, 550 and 1000 for different chains, depending on tests passing (aave allowing it)
            // uint256 fee = (amounts[i] * aavePremium) / 1000000;
            deal(assets[i], address(tremor), (amounts[i] * aavePremium) / 1000000);
        }
        // simulating uniV3 flash-loan fees, which should come from flash-loan profits
        IUniswapV3Pool uniPool;
        for (uint256 i = 0; i < uniPools.length; i++) {
            (address token0, address token1, uint16 fee) = abi.decode(uniPools[i], (address, address, uint16));
            uniPool = IUniswapV3Pool(
                PoolAddress.computeAddress(
                    uniV3Factory, PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee})
                )
            );
            deal(
                token0,
                address(tremor),
                IERC20(token0).balanceOf(address(tremor)) + (IERC20(token0).balanceOf(address(uniPool)) * fee) / 1000000
            );
            deal(
                token1,
                address(tremor),
                IERC20(token1).balanceOf(address(tremor)) + (IERC20(token1).balanceOf(address(uniPool)) * fee) / 1000000
            );
        }
    }

    // Try to break asset uniqueness in HashSet invariant
    function try_duplicateAssets(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 100 ether);

        // Create arrays with duplicate assets
        address[] memory assets = new address[](2);
        assets[0] = addresses.WETH;
        assets[1] = addresses.WETH; // Duplicate WETH

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount + 404;

        bytes memory providers =
            abi.encode(address(pool), addresses.provider.BAL_VAULT, addresses.provider.UNI_V3_FACTORY);
        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, new bytes[](0));
        tremor.dominoeFlashLoans(providers, assets, amounts, new IERC20[](0), new uint256[](0), new bytes[](0));
    }

    // Initiate calls to test approvals safety invariant
    function try_breakingApprovals(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 100 ether);

        // giving it an approval just below the amount to see if it
        // gets overwritten and used by the flashloan to change to 0
        vm.prank(address(tremor));
        IERC20(addresses.WETH).approve(address(pool), amount - 1);

        address[] memory assets = new address[](1);
        assets[0] = addresses.WETH;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes memory providers =
            abi.encode(address(pool), addresses.provider.BAL_VAULT, addresses.provider.UNI_V3_FACTORY);
        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, new bytes[](0));
        tremor.dominoeFlashLoans(providers, assets, amounts, new IERC20[](0), new uint256[](0), new bytes[](0));
    }
}
