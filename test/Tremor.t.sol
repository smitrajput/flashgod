// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import {Tremor} from "../src/Tremor.sol";
import {Addresses} from "../src/config/Addresses.sol";
import {Test, console, Vm} from "forge-std/Test.sol";

contract TremorTest is Test {
    Tremor public tremor;
    IPool public pool;

    struct UniPool {
        address token0;
        address token1;
        uint16 fee;
    }

    function setUp() public {
        // Empty setup - each test will handle its own setup
    }

    function test_dominoeFlashLoans_ethereum() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.EthereumAddresses memory addresses = Addresses.ethereumAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](8);
        assets[0] = addresses.WETH;
        assets[1] = addresses.WBTC;
        assets[2] = addresses.USDC;
        assets[3] = addresses.WE_ETH;
        assets[4] = addresses.WSTETH;
        assets[5] = addresses.CB_BTC;
        assets[6] = addresses.LINK;
        assets[7] = addresses.RETH;

        uint256[] memory amounts = new uint256[](8);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == addresses.USDC) {
                amounts[i] = (maxFlashloanable * 95) / 100; // could test with more
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        /// @dev specify all the assets you want to flash loan from balancer, here
        /// NOTE: balancer likes its assets ascending ordered
        IERC20[] memory balancerAssets = new IERC20[](4);
        balancerAssets[0] = IERC20(addresses.WSTETH);
        balancerAssets[1] = IERC20(addresses.AAVE);
        balancerAssets[2] = IERC20(addresses.BAL);
        balancerAssets[3] = IERC20(addresses.WETH);

        // balancer charges 0 flash-loan fees <3

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 100% of balancer TVL
        uint256[] memory balancerAmounts = new uint256[](4);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balancerAmounts[i] = balancerAssets[i].balanceOf(addresses.provider.BAL_VAULT);
        }

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        UniPool[] memory uniPoolValues = new UniPool[](4);
        uniPoolValues[0] = UniPool({token0: addresses.USDC, token1: addresses.WETH, fee: 500});
        uniPoolValues[1] = UniPool({token0: addresses.WBTC, token1: addresses.WETH, fee: 3000});
        uniPoolValues[2] = UniPool({token0: addresses.WETH, token1: addresses.USDT, fee: 3000});
        uniPoolValues[3] = UniPool({token0: addresses.USDC, token1: addresses.WETH, fee: 3000});

        address[] memory uniPoolAddresses = new address[](4);
        for (uint256 i = 0; i < uniPoolValues.length; i++) {
            uniPoolAddresses[i] = PoolAddress.computeAddress(
                addresses.provider.UNI_V3_FACTORY,
                PoolAddress.PoolKey({
                    token0: uniPoolValues[i].token0,
                    token1: uniPoolValues[i].token1,
                    fee: uniPoolValues[i].fee
                })
            );
        }

        /// @dev specify all pool token amounts you want to flash loan, at 3rd and 4th arguments,
        /// currently loaning 99.9% of pool token amounts
        bytes[] memory uniPools = new bytes[](4);
        for (uint256 i = 0; i < uniPoolAddresses.length; i++) {
            uniPools[i] = abi.encode(
                uniPoolValues[i].token0,
                uniPoolValues[i].token1,
                uniPoolValues[i].fee,
                (IERC20(uniPoolValues[i].token0).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000,
                (IERC20(uniPoolValues[i].token1).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000
            );
        }

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, balancerAmounts, uniPools);
    }

    function test_dominoeFlashLoans_arbitrum() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.ArbitrumAddresses memory addresses = Addresses.arbitrumAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](8);
        assets[0] = addresses.WETH;
        assets[1] = addresses.WBTC;
        assets[2] = addresses.USDC;
        assets[3] = addresses.WE_ETH;
        assets[4] = addresses.WSTETH;
        assets[5] = addresses.ARB;
        assets[6] = addresses.LINK;
        assets[7] = addresses.RETH;

        uint256[] memory amounts = new uint256[](8);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == addresses.USDC && maxFlashloanable >= 50_000_000) {
                amounts[i] = maxFlashloanable - 50_000_000;
            } else if (maxFlashloanable >= (10 ** IERC20Metadata(assets[i]).decimals())) {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        /// @dev specify all the assets you want to flash loan from balancer, here
        /// NOTE: balancer likes its assets ascending ordered
        IERC20[] memory balancerAssets = new IERC20[](4);
        balancerAssets[0] = IERC20(addresses.WBTC);
        balancerAssets[1] = IERC20(addresses.RDNT);
        balancerAssets[2] = IERC20(addresses.WETH);
        balancerAssets[3] = IERC20(addresses.USDC);

        // balancer charges 0 flash-loan fees <3

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 100% of balancer TVL
        uint256[] memory balancerAmounts = new uint256[](4);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balancerAmounts[i] = balancerAssets[i].balanceOf(addresses.provider.BAL_VAULT);
        }

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        UniPool[] memory uniPoolValues = new UniPool[](4);
        uniPoolValues[0] = UniPool({token0: addresses.WBTC, token1: addresses.WETH, fee: 500});
        uniPoolValues[1] = UniPool({token0: addresses.WETH, token1: addresses.USDC, fee: 500});
        uniPoolValues[2] = UniPool({token0: addresses.WETH, token1: addresses.GMX, fee: 10000});
        uniPoolValues[3] = UniPool({token0: addresses.WBTC, token1: addresses.USDT, fee: 500});

        address[] memory uniPoolAddresses = new address[](4);
        for (uint256 i = 0; i < uniPoolValues.length; i++) {
            uniPoolAddresses[i] = PoolAddress.computeAddress(
                addresses.provider.UNI_V3_FACTORY,
                PoolAddress.PoolKey({
                    token0: uniPoolValues[i].token0,
                    token1: uniPoolValues[i].token1,
                    fee: uniPoolValues[i].fee
                })
            );
        }

        /// @dev specify all pool token amounts you want to flash loan, at 3rd and 4th arguments,
        /// currently loaning 99.9% of pool token amounts
        bytes[] memory uniPools = new bytes[](4);
        for (uint256 i = 0; i < uniPoolAddresses.length; i++) {
            uniPools[i] = abi.encode(
                uniPoolValues[i].token0,
                uniPoolValues[i].token1,
                uniPoolValues[i].fee,
                (IERC20(uniPoolValues[i].token0).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000,
                (IERC20(uniPoolValues[i].token1).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000
            );
        }

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 550, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, balancerAmounts, uniPools);
    }

    function test_dominoeFlashLoans_optimism() public {
        vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.OptimismAddresses memory addresses = Addresses.optimismAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](8);
        assets[0] = addresses.WETH;
        assets[1] = addresses.USDC;
        assets[2] = addresses.WBTC;
        assets[3] = addresses.WSTETH;
        assets[4] = addresses.OP;
        assets[5] = addresses.USDT;
        assets[6] = addresses.LINK;
        assets[7] = addresses.RETH;

        uint256[] memory amounts = new uint256[](8);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == addresses.USDC || assets[i] == addresses.USDT) {
                amounts[i] = (maxFlashloanable * 95) / 100;
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        /// @dev specify all the assets you want to flash loan from balancer, here
        IERC20[] memory balancerAssets = new IERC20[](0);

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 0% of balancer TVL
        uint256[] memory balancerAmounts = new uint256[](0);

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        UniPool[] memory uniPoolValues = new UniPool[](3);
        uniPoolValues[0] = UniPool({token0: addresses.WETH, token1: addresses.OP, fee: 3000});
        uniPoolValues[1] = UniPool({token0: addresses.USDC, token1: addresses.WETH, fee: 500});
        uniPoolValues[2] = UniPool({token0: addresses.WETH, token1: addresses.WBTC, fee: 500});

        address[] memory uniPoolAddresses = new address[](3);
        for (uint256 i = 0; i < uniPoolValues.length; i++) {
            uniPoolAddresses[i] = PoolAddress.computeAddress(
                addresses.provider.UNI_V3_FACTORY,
                PoolAddress.PoolKey({
                    token0: uniPoolValues[i].token0,
                    token1: uniPoolValues[i].token1,
                    fee: uniPoolValues[i].fee
                })
            );
        }

        /// @dev specify all pool token amounts you want to flash loan, at 3rd and 4th arguments,
        /// currently loaning 99.9% of pool token amounts
        bytes[] memory uniPools = new bytes[](3);
        for (uint256 i = 0; i < uniPoolAddresses.length; i++) {
            uniPools[i] = abi.encode(
                uniPoolValues[i].token0,
                uniPoolValues[i].token1,
                uniPoolValues[i].fee,
                (IERC20(uniPoolValues[i].token0).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000,
                (IERC20(uniPoolValues[i].token1).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000
            );
        }

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, balancerAmounts, uniPools);
    }

    function test_dominoeFlashLoans_polygon() public {
        vm.createSelectFork(vm.envString("POLYGON_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.PolygonAddresses memory addresses = Addresses.polygonAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](7);
        assets[0] = addresses.WBTC;
        assets[1] = addresses.WETH;
        assets[2] = addresses.USDT;
        assets[3] = addresses.USDC;
        assets[4] = addresses.MATICX;
        assets[5] = addresses.WSTETH;
        assets[6] = addresses.WMATIC;

        uint256[] memory amounts = new uint256[](7);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == addresses.USDC || assets[i] == addresses.USDT) {
                amounts[i] = (maxFlashloanable * 95) / 100;
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        /// @dev specify all the assets you want to flash loan from balancer, here
        IERC20[] memory balancerAssets = new IERC20[](5);
        balancerAssets[0] = IERC20(addresses.WMATIC);
        balancerAssets[1] = IERC20(addresses.USDC);
        balancerAssets[2] = IERC20(addresses.WETH);
        balancerAssets[3] = IERC20(addresses.TEL);
        balancerAssets[4] = IERC20(addresses.MATICX);

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 100% of balancer TVL
        uint256[] memory balancerAmounts = new uint256[](5);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balancerAmounts[i] = balancerAssets[i].balanceOf(addresses.provider.BAL_VAULT);
        }

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        UniPool[] memory uniPoolValues = new UniPool[](3);
        uniPoolValues[0] = UniPool({token0: addresses.WBTC, token1: addresses.WETH, fee: 500});
        uniPoolValues[1] = UniPool({token0: addresses.USDCe, token1: addresses.USDC, fee: 100});
        uniPoolValues[2] = UniPool({token0: addresses.USDCe, token1: addresses.WETH, fee: 500});

        address[] memory uniPoolAddresses = new address[](3);
        for (uint256 i = 0; i < uniPoolValues.length; i++) {
            uniPoolAddresses[i] = PoolAddress.computeAddress(
                addresses.provider.UNI_V3_FACTORY,
                PoolAddress.PoolKey({
                    token0: uniPoolValues[i].token0,
                    token1: uniPoolValues[i].token1,
                    fee: uniPoolValues[i].fee
                })
            );
        }

        /// @dev specify all pool token amounts you want to flash loan, at 3rd and 4th arguments,
        /// currently loaning 99.9% of pool token amounts
        bytes[] memory uniPools = new bytes[](3);
        for (uint256 i = 0; i < uniPoolAddresses.length; i++) {
            uniPools[i] = abi.encode(
                uniPoolValues[i].token0,
                uniPoolValues[i].token1,
                uniPoolValues[i].fee,
                (IERC20(uniPoolValues[i].token0).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000,
                (IERC20(uniPoolValues[i].token1).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000
            );
        }

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, balancerAmounts, uniPools);
    }

    function test_dominoeFlashLoans_base() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.BaseAddresses memory addresses = Addresses.baseAddresses();

        // Skip if ADDRESSES_PROVIDER is not available
        if (addresses.provider.ADDRESSES_PROVIDER == address(0)) return;

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](6);
        assets[0] = addresses.WETH;
        assets[1] = addresses.WE_ETH;
        assets[2] = addresses.CB_ETH;
        assets[3] = addresses.USDC;
        assets[4] = addresses.WSTETH;
        assets[5] = addresses.CB_BTC;

        uint256[] memory amounts = new uint256[](6);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == addresses.USDC) {
                amounts[i] = (maxFlashloanable * 95) / 100;
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        /// @dev specify all the assets you want to flash loan from balancer, here
        IERC20[] memory balancerAssets = new IERC20[](3);
        balancerAssets[0] = IERC20(addresses.WETH);
        balancerAssets[1] = IERC20(addresses.WSTETH);
        balancerAssets[2] = IERC20(addresses.RDNT);

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 100% of balancer TVL
        uint256[] memory balancerAmounts = new uint256[](3);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balancerAmounts[i] = balancerAssets[i].balanceOf(addresses.provider.BAL_VAULT);
        }

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        UniPool[] memory uniPoolValues = new UniPool[](3);
        uniPoolValues[0] = UniPool({token0: addresses.WETH, token1: addresses.USDC, fee: 500});
        uniPoolValues[1] = UniPool({token0: addresses.WETH, token1: addresses.DEGEN, fee: 3000});
        uniPoolValues[2] = UniPool({token0: addresses.WETH, token1: addresses.CB_BTC, fee: 3000});

        address[] memory uniPoolAddresses = new address[](3);
        for (uint256 i = 0; i < uniPoolValues.length; i++) {
            uniPoolAddresses[i] = PoolAddress.computeAddress(
                addresses.provider.UNI_V3_FACTORY,
                PoolAddress.PoolKey({
                    token0: uniPoolValues[i].token0,
                    token1: uniPoolValues[i].token1,
                    fee: uniPoolValues[i].fee
                })
            );
        }

        /// @dev specify all pool token amounts you want to flash loan, at 3rd and 4th arguments,
        /// currently loaning 99.9% of pool token amounts
        bytes[] memory uniPools = new bytes[](3);
        for (uint256 i = 0; i < uniPoolAddresses.length; i++) {
            uniPools[i] = abi.encode(
                uniPoolValues[i].token0,
                uniPoolValues[i].token1,
                uniPoolValues[i].fee,
                (IERC20(uniPoolValues[i].token0).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000,
                (IERC20(uniPoolValues[i].token1).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000
            );
        }

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, balancerAmounts, uniPools);
    }

    function test_dominoeFlashLoans_avalanche() public {
        vm.createSelectFork(vm.envString("AVAX_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.AvalancheAddresses memory addresses = Addresses.avalancheAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH_e
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](7);
        assets[0] = addresses.BTC_b;
        assets[1] = addresses.WAVAX;
        assets[2] = addresses.USDC;
        assets[3] = addresses.sAVAX;
        assets[4] = addresses.USDT;
        assets[5] = addresses.WETH_e;
        assets[6] = addresses.LINK_e;

        uint256[] memory amounts = new uint256[](7);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == addresses.USDC || assets[i] == addresses.USDT) {
                amounts[i] = (maxFlashloanable * 95) / 100; // could test with more
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        /// @dev specify all the assets you want to flash loan from balancer, here
        /// NOTE: balancer likes its assets ascending ordered
        IERC20[] memory balancerAssets = new IERC20[](4);
        balancerAssets[0] = IERC20(addresses.sAVAX);
        balancerAssets[1] = IERC20(addresses.ggAVAX);
        balancerAssets[2] = IERC20(addresses.WAVAX);
        balancerAssets[3] = IERC20(addresses.USDC);

        // balancer charges 0 flash-loan fees <3

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 100% of balancer TVL
        uint256[] memory balancerAmounts = new uint256[](4);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balancerAmounts[i] = balancerAssets[i].balanceOf(addresses.provider.BAL_VAULT);
        }

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        UniPool[] memory uniPoolValues = new UniPool[](3);
        uniPoolValues[0] = UniPool({token0: addresses.WETH_e, token1: addresses.WAVAX, fee: 500});
        uniPoolValues[1] = UniPool({token0: addresses.WAVAX, token1: addresses.USDC, fee: 500});
        uniPoolValues[2] = UniPool({token0: addresses.BTC_b, token1: addresses.USDC, fee: 3000});

        address[] memory uniPoolAddresses = new address[](3);
        for (uint256 i = 0; i < uniPoolValues.length; i++) {
            uniPoolAddresses[i] = PoolAddress.computeAddress(
                addresses.provider.UNI_V3_FACTORY,
                PoolAddress.PoolKey({
                    token0: uniPoolValues[i].token0,
                    token1: uniPoolValues[i].token1,
                    fee: uniPoolValues[i].fee
                })
            );
        }

        /// @dev specify all pool token amounts you want to flash loan, at 3rd and 4th arguments,
        /// currently loaning 99.9% of pool token amounts
        bytes[] memory uniPools = new bytes[](3);
        for (uint256 i = 0; i < uniPoolAddresses.length; i++) {
            uniPools[i] = abi.encode(
                uniPoolValues[i].token0,
                uniPoolValues[i].token1,
                uniPoolValues[i].fee,
                (IERC20(uniPoolValues[i].token0).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000,
                (IERC20(uniPoolValues[i].token1).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000
            );
        }

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, balancerAmounts, uniPools);
    }

    function test_dominoeFlashLoans_bsc() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.BscAddresses memory addresses = Addresses.bscAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.ETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](7);
        assets[0] = addresses.BTCB;
        assets[1] = addresses.WBNB;
        assets[2] = addresses.USDC;
        assets[3] = addresses.ETH;
        assets[4] = addresses.USDT;
        assets[5] = addresses.WSTETH;
        assets[6] = addresses.FDUSD;

        uint256[] memory amounts = new uint256[](7);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            // NOTE: occasional changes in max-flashloanable amounts observed for some stables
            if (assets[i] == addresses.USDC || assets[i] == addresses.FDUSD) {
                amounts[i] = (maxFlashloanable * 95) / 100; // could test with more
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        /// @dev specify all the assets you want to flash loan from balancer, here
        /// NOTE: balancer likes its assets ascending ordered
        IERC20[] memory balancerAssets = new IERC20[](0);

        // balancer charges 0 flash-loan fees <3

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 0% of balancer TVL
        uint256[] memory balancerAmounts = new uint256[](0);

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        UniPool[] memory uniPoolValues = new UniPool[](3);
        uniPoolValues[0] = UniPool({token0: addresses.ETH, token1: addresses.WBNB, fee: 500});
        uniPoolValues[1] = UniPool({token0: addresses.USDT, token1: addresses.USDC, fee: 100});
        uniPoolValues[2] = UniPool({token0: addresses.ETH, token1: addresses.USDT, fee: 500});

        address[] memory uniPoolAddresses = new address[](3);
        for (uint256 i = 0; i < uniPoolValues.length; i++) {
            uniPoolAddresses[i] = PoolAddress.computeAddress(
                addresses.provider.UNI_V3_FACTORY,
                PoolAddress.PoolKey({
                    token0: uniPoolValues[i].token0,
                    token1: uniPoolValues[i].token1,
                    fee: uniPoolValues[i].fee
                })
            );
        }

        /// @dev specify all pool token amounts you want to flash loan, at 3rd and 4th arguments,
        /// currently loaning 99.9% of pool token amounts
        bytes[] memory uniPools = new bytes[](3);
        for (uint256 i = 0; i < uniPoolAddresses.length; i++) {
            uniPools[i] = abi.encode(
                uniPoolValues[i].token0,
                uniPoolValues[i].token1,
                uniPoolValues[i].fee,
                (IERC20(uniPoolValues[i].token0).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000,
                (IERC20(uniPoolValues[i].token1).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000
            );
        }

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, balancerAmounts, uniPools);
    }

    function test_transientStorageCleanup() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.EthereumAddresses memory addresses = Addresses.ethereumAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](8);
        assets[0] = addresses.WETH;
        assets[1] = addresses.WBTC;
        assets[2] = addresses.USDC;
        assets[3] = addresses.WE_ETH;
        assets[4] = addresses.WSTETH;
        assets[5] = addresses.CB_BTC;
        assets[6] = addresses.LINK;
        assets[7] = addresses.RETH;

        uint256[] memory amounts = new uint256[](8);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == addresses.USDC) {
                amounts[i] = (maxFlashloanable * 95) / 100; // could test with more
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        /// @dev specify all the assets you want to flash loan from balancer, here
        /// NOTE: balancer likes its assets ascending ordered
        IERC20[] memory balancerAssets = new IERC20[](4);
        balancerAssets[0] = IERC20(addresses.WSTETH);
        balancerAssets[1] = IERC20(addresses.AAVE);
        balancerAssets[2] = IERC20(addresses.BAL);
        balancerAssets[3] = IERC20(addresses.WETH);

        // balancer charges 0 flash-loan fees <3

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 100% of balancer TVL
        uint256[] memory balancerAmounts = new uint256[](4);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balancerAmounts[i] = balancerAssets[i].balanceOf(addresses.provider.BAL_VAULT);
        }

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        UniPool[] memory uniPoolValues = new UniPool[](4);
        uniPoolValues[0] = UniPool({token0: addresses.USDC, token1: addresses.WETH, fee: 500});
        uniPoolValues[1] = UniPool({token0: addresses.WBTC, token1: addresses.WETH, fee: 3000});
        uniPoolValues[2] = UniPool({token0: addresses.WETH, token1: addresses.USDT, fee: 3000});
        uniPoolValues[3] = UniPool({token0: addresses.USDC, token1: addresses.WETH, fee: 3000});

        address[] memory uniPoolAddresses = new address[](4);
        for (uint256 i = 0; i < uniPoolValues.length; i++) {
            uniPoolAddresses[i] = PoolAddress.computeAddress(
                addresses.provider.UNI_V3_FACTORY,
                PoolAddress.PoolKey({
                    token0: uniPoolValues[i].token0,
                    token1: uniPoolValues[i].token1,
                    fee: uniPoolValues[i].fee
                })
            );
        }

        /// @dev specify all pool token amounts you want to flash loan, at 3rd and 4th arguments,
        /// currently loaning 99.9% of pool token amounts
        bytes[] memory uniPools = new bytes[](4);
        for (uint256 i = 0; i < uniPoolAddresses.length; i++) {
            uniPools[i] = abi.encode(
                uniPoolValues[i].token0,
                uniPoolValues[i].token1,
                uniPoolValues[i].fee,
                (IERC20(uniPoolValues[i].token0).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000,
                (IERC20(uniPoolValues[i].token1).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000
            );
        }

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, balancerAmounts, uniPools);
        /// NOTE: this txn is the same txn in which dominoeFlashLoans() is called, so
        /// the same transient storage slots are available in this test, which were used
        /// in the dominoeFlashLoans() call.
        /// Checking 4 slots atm
        assembly {
            if iszero(eq(tload(0xBADBABE), 0)) { revert(0, 0) } // revert with no message

            if iszero(eq(tload(0xD15EA5ED), 0)) { revert(0, 0) }

            if iszero(eq(tload(0xDEFEA7ED), 0)) { revert(0, 0) }

            if iszero(eq(tload(0xDEADFACE), 0)) { revert(0, 0) }
        }
    }

    function test_revert_LengthMismatchAave() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.EthereumAddresses memory addresses = Addresses.ethereumAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](8);
        assets[0] = addresses.WETH;
        assets[1] = addresses.WBTC;
        assets[2] = addresses.USDC;
        assets[3] = addresses.WE_ETH;
        assets[4] = addresses.WSTETH;
        assets[5] = addresses.CB_BTC;
        assets[6] = addresses.LINK;
        assets[7] = addresses.RETH;

        // amounts.length != assets.length
        uint256[] memory amounts = new uint256[](7);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < amounts.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == addresses.USDC) {
                amounts[i] = (maxFlashloanable * 95) / 100; // could test with more
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        /// @dev specify all the assets you want to flash loan from balancer, here
        /// NOTE: balancer likes its assets ascending ordered
        IERC20[] memory balancerAssets = new IERC20[](4);
        balancerAssets[0] = IERC20(addresses.WSTETH);
        balancerAssets[1] = IERC20(addresses.AAVE);
        balancerAssets[2] = IERC20(addresses.BAL);
        balancerAssets[3] = IERC20(addresses.WETH);

        // balancer charges 0 flash-loan fees <3

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 100% of balancer TVL
        uint256[] memory balancerAmounts = new uint256[](4);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balancerAmounts[i] = balancerAssets[i].balanceOf(addresses.provider.BAL_VAULT);
        }

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        UniPool[] memory uniPoolValues = new UniPool[](4);
        uniPoolValues[0] = UniPool({token0: addresses.USDC, token1: addresses.WETH, fee: 500});
        uniPoolValues[1] = UniPool({token0: addresses.WBTC, token1: addresses.WETH, fee: 3000});
        uniPoolValues[2] = UniPool({token0: addresses.WETH, token1: addresses.USDT, fee: 3000});
        uniPoolValues[3] = UniPool({token0: addresses.USDC, token1: addresses.WETH, fee: 3000});

        address[] memory uniPoolAddresses = new address[](4);
        for (uint256 i = 0; i < uniPoolValues.length; i++) {
            uniPoolAddresses[i] = PoolAddress.computeAddress(
                addresses.provider.UNI_V3_FACTORY,
                PoolAddress.PoolKey({
                    token0: uniPoolValues[i].token0,
                    token1: uniPoolValues[i].token1,
                    fee: uniPoolValues[i].fee
                })
            );
        }

        /// @dev specify all pool token amounts you want to flash loan, at 3rd and 4th arguments,
        /// currently loaning 99.9% of pool token amounts
        bytes[] memory uniPools = new bytes[](4);
        for (uint256 i = 0; i < uniPoolAddresses.length; i++) {
            uniPools[i] = abi.encode(
                uniPoolValues[i].token0,
                uniPoolValues[i].token1,
                uniPoolValues[i].fee,
                (IERC20(uniPoolValues[i].token0).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000,
                (IERC20(uniPoolValues[i].token1).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000
            );
        }

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        vm.expectRevert(Tremor.LengthMismatchAave.selector);
        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, balancerAmounts, uniPools);
    }

    function test_revert_LengthMismatchBalancer() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.EthereumAddresses memory addresses = Addresses.ethereumAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](8);
        assets[0] = addresses.WETH;
        assets[1] = addresses.WBTC;
        assets[2] = addresses.USDC;
        assets[3] = addresses.WE_ETH;
        assets[4] = addresses.WSTETH;
        assets[5] = addresses.CB_BTC;
        assets[6] = addresses.LINK;
        assets[7] = addresses.RETH;

        uint256[] memory amounts = new uint256[](8);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == addresses.USDC) {
                amounts[i] = (maxFlashloanable * 95) / 100; // could test with more
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        /// @dev specify all the assets you want to flash loan from balancer, here
        /// NOTE: balancer likes its assets ascending ordered
        IERC20[] memory balancerAssets = new IERC20[](4);
        balancerAssets[0] = IERC20(addresses.WSTETH);
        balancerAssets[1] = IERC20(addresses.AAVE);
        balancerAssets[2] = IERC20(addresses.BAL);
        balancerAssets[3] = IERC20(addresses.WETH);

        // balancer charges 0 flash-loan fees <3

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 100% of balancer TVL
        // balancerAmounts.length != balancerAssets.length
        uint256[] memory balancerAmounts = new uint256[](3);
        for (uint256 i = 0; i < balancerAmounts.length; i++) {
            balancerAmounts[i] = balancerAssets[i].balanceOf(addresses.provider.BAL_VAULT);
        }

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        UniPool[] memory uniPoolValues = new UniPool[](4);
        uniPoolValues[0] = UniPool({token0: addresses.USDC, token1: addresses.WETH, fee: 500});
        uniPoolValues[1] = UniPool({token0: addresses.WBTC, token1: addresses.WETH, fee: 3000});
        uniPoolValues[2] = UniPool({token0: addresses.WETH, token1: addresses.USDT, fee: 3000});
        uniPoolValues[3] = UniPool({token0: addresses.USDC, token1: addresses.WETH, fee: 3000});

        address[] memory uniPoolAddresses = new address[](4);
        for (uint256 i = 0; i < uniPoolValues.length; i++) {
            uniPoolAddresses[i] = PoolAddress.computeAddress(
                addresses.provider.UNI_V3_FACTORY,
                PoolAddress.PoolKey({
                    token0: uniPoolValues[i].token0,
                    token1: uniPoolValues[i].token1,
                    fee: uniPoolValues[i].fee
                })
            );
        }

        /// @dev specify all pool token amounts you want to flash loan, at 3rd and 4th arguments,
        /// currently loaning 99.9% of pool token amounts
        bytes[] memory uniPools = new bytes[](4);
        for (uint256 i = 0; i < uniPoolAddresses.length; i++) {
            uniPools[i] = abi.encode(
                uniPoolValues[i].token0,
                uniPoolValues[i].token1,
                uniPoolValues[i].fee,
                (IERC20(uniPoolValues[i].token0).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000,
                (IERC20(uniPoolValues[i].token1).balanceOf(address(uniPoolAddresses[i])) * 999) / 1000
            );
        }

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        vm.expectRevert(Tremor.LengthMismatchBalancer.selector);
        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, balancerAmounts, uniPools);
    }

    function test_revert_NotAavePool() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.EthereumAddresses memory addresses = Addresses.ethereumAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from aave, here
        address[] memory assets = new address[](8);
        assets[0] = addresses.WETH;
        assets[1] = addresses.WBTC;
        assets[2] = addresses.USDC;
        assets[3] = addresses.WE_ETH;
        assets[4] = addresses.WSTETH;
        assets[5] = addresses.CB_BTC;
        assets[6] = addresses.LINK;
        assets[7] = addresses.RETH;

        uint256[] memory amounts = new uint256[](8);
        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == addresses.USDC) {
                amounts[i] = (maxFlashloanable * 95) / 100; // could test with more
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        uint256[] memory premiums = new uint256[](8);

        vm.expectRevert(Tremor.NotAavePool.selector);
        tremor.executeOperation(assets, amounts, premiums, address(this), bytes(""));
    }

    function test_revert_NotBalancerVault() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.EthereumAddresses memory addresses = Addresses.ethereumAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        /// @dev specify all the assets you want to flash loan from balancer, here
        /// NOTE: balancer likes its assets ascending ordered
        IERC20[] memory balancerAssets = new IERC20[](4);
        balancerAssets[0] = IERC20(addresses.WSTETH);
        balancerAssets[1] = IERC20(addresses.AAVE);
        balancerAssets[2] = IERC20(addresses.BAL);
        balancerAssets[3] = IERC20(addresses.WETH);

        // balancer charges 0 flash-loan fees <3

        /// @dev specify all the asset amounts you want to flash loan from balancer, here
        /// NOTE: currently loaning 100% of balancer TVL
        uint256[] memory balancerAmounts = new uint256[](4);
        for (uint256 i = 0; i < balancerAssets.length; i++) {
            balancerAmounts[i] = balancerAssets[i].balanceOf(addresses.provider.BAL_VAULT);
        }

        vm.expectRevert(Tremor.NotBalancerVault.selector);
        tremor.receiveFlashLoan(balancerAssets, balancerAmounts, new uint256[](0), bytes(""));
    }

    function test_revert_NotUniPool() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        console.log("Chain ID:", block.chainid);

        Addresses.EthereumAddresses memory addresses = Addresses.ethereumAddresses();

        pool = IPool(IPoolAddressesProvider(addresses.provider.ADDRESSES_PROVIDER).getPool());

        tremor = new Tremor(
            addresses.provider.ADDRESSES_PROVIDER,
            address(pool),
            addresses.provider.UNI_V3_FACTORY,
            addresses.provider.SWAP_ROUTER,
            addresses.provider.BAL_VAULT,
            addresses.WETH
        );

        vm.label(address(pool), "AAVE_POOL");

        vm.expectRevert(Tremor.NotUniPool.selector);
        tremor.uniswapV3FlashCallback(0, 0, bytes(""));
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

    function toLowerCase(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // Convert uppercase to lowercase if needed
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    function toUpperCase(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bUpper = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // Convert lowercase to uppercase if needed
            if ((uint8(bStr[i]) >= 97) && (uint8(bStr[i]) <= 122)) {
                bUpper[i] = bytes1(uint8(bStr[i]) - 32);
            } else {
                bUpper[i] = bStr[i];
            }
        }
        return string(bUpper);
    }
}
