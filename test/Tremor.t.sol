// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Tremor} from "../src/Tremor.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {DeployAaveV3} from "../script/DeployAaveV3.s.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {Pair1Flash} from "../src/Pair1Flash.sol";
import {Pair2Flash} from "../src/Pair2Flash.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import {Test, console, Vm} from "forge-std/Test.sol";
import {Addresses} from "../src/config/Addresses.sol";
import {EnumerableSetLib} from "@solady/src/utils/EnumerableSetLib.sol";

contract TremorTest is Test {
    Tremor public tremor;
    IPool public pool;

    // using EnumerableSetLib for EnumerableSetLib.AddressSet;

    function setUp() public {
        // Empty setup - each test will handle its own setup
    }

    function test_dominoeFlashLoans_ethereum() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

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
        address[] memory balancerAssets = new address[](4);
        balancerAssets[0] = addresses.WSTETH;
        balancerAssets[1] = addresses.AAVE;
        balancerAssets[2] = addresses.BAL;
        balancerAssets[3] = addresses.WETH;

        // balancer charges 0 flash-loan fees <3

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        bytes[] memory uniPools = new bytes[](4);
        uniPools[0] = abi.encode(addresses.USDC, addresses.WETH, 500);
        uniPools[1] = abi.encode(addresses.WBTC, addresses.WETH, 3000);
        uniPools[2] = abi.encode(addresses.WETH, addresses.USDT, 3000);
        uniPools[3] = abi.encode(addresses.USDC, addresses.WETH, 3000);

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, uniPools);
    }

    function test_dominoeFlashLoans_arbitrum() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

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
        address[] memory balancerAssets = new address[](4);
        balancerAssets[0] = addresses.WBTC;
        balancerAssets[1] = addresses.RDNT;
        balancerAssets[2] = addresses.WETH;
        balancerAssets[3] = addresses.USDC;

        // balancer charges 0 flash-loan fees <3

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        bytes[] memory uniPools = new bytes[](4);
        uniPools[0] = abi.encode(addresses.WBTC, addresses.WETH, 500);
        uniPools[1] = abi.encode(addresses.WETH, addresses.USDC, 500);
        uniPools[2] = abi.encode(addresses.WETH, addresses.GMX, 10000);
        uniPools[3] = abi.encode(addresses.WBTC, addresses.USDT, 500);

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 550, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, uniPools);
    }

    function test_dominoeFlashLoans_optimism() public {
        vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"));

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
        address[] memory balancerAssets = new address[](0);

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        bytes[] memory uniPools = new bytes[](3);
        uniPools[0] = abi.encode(addresses.WETH, addresses.OP, uint16(3000));
        uniPools[1] = abi.encode(addresses.USDC, addresses.WETH, uint16(500));
        uniPools[2] = abi.encode(addresses.WETH, addresses.WBTC, uint16(500));

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, uniPools);
    }

    function test_dominoeFlashLoans_polygon() public {
        vm.createSelectFork(vm.envString("POLYGON_RPC_URL"));

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
        address[] memory balancerAssets = new address[](5);
        balancerAssets[0] = addresses.WMATIC;
        balancerAssets[1] = addresses.USDC;
        balancerAssets[2] = addresses.WETH;
        balancerAssets[3] = addresses.TEL;
        balancerAssets[4] = addresses.MATICX;

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        bytes[] memory uniPools = new bytes[](3);
        uniPools[0] = abi.encode(addresses.WBTC, addresses.WETH, uint16(500));
        uniPools[1] = abi.encode(addresses.USDCe, addresses.USDC, uint16(100));
        uniPools[2] = abi.encode(addresses.USDCe, addresses.WETH, uint16(500));

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, uniPools);
    }

    function test_dominoeFlashLoans_base() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

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
        address[] memory balancerAssets = new address[](3);
        balancerAssets[0] = addresses.WETH;
        balancerAssets[1] = addresses.WSTETH;
        balancerAssets[2] = addresses.RDNT;

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        bytes[] memory uniPools = new bytes[](3);
        uniPools[0] = abi.encode(addresses.WETH, addresses.USDC, uint16(500));
        uniPools[1] = abi.encode(addresses.WETH, addresses.DEGEN, uint16(3000));
        uniPools[2] = abi.encode(addresses.WETH, addresses.CB_BTC, uint16(3000));

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, uniPools);
    }

    function test_dominoeFlashLoans_avalanche() public {
        vm.createSelectFork(vm.envString("AVAX_RPC_URL"));

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
        address[] memory balancerAssets = new address[](4);
        balancerAssets[0] = addresses.sAVAX;
        balancerAssets[1] = addresses.ggAVAX;
        balancerAssets[2] = addresses.WAVAX;
        balancerAssets[3] = addresses.USDC;

        // balancer charges 0 flash-loan fees <3

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        bytes[] memory uniPools = new bytes[](3);
        uniPools[0] = abi.encode(addresses.WETH_e, addresses.WAVAX, 500);
        uniPools[1] = abi.encode(addresses.WAVAX, addresses.USDC, 500);
        uniPools[2] = abi.encode(addresses.BTC_b, addresses.USDC, 3000);

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, uniPools);
    }

    function test_dominoeFlashLoans_bsc() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"));

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
        address[] memory balancerAssets = new address[](0);

        // balancer charges 0 flash-loan fees <3

        /// @dev (token0, token1, poolFeeTier) represents a pool, so specify all the pools you
        /// want to flash loan assets from
        /// NOTE: uniV3 likes its pool tokens in certain order
        bytes[] memory uniPools = new bytes[](3);
        uniPools[0] = abi.encode(addresses.ETH, addresses.WBNB, 500);
        uniPools[1] = abi.encode(addresses.USDT, addresses.USDC, 100);
        uniPools[2] = abi.encode(addresses.ETH, addresses.USDT, 500);

        simulateAaveAndUniswapFlashLoanFees(assets, amounts, 1000, addresses.provider.UNI_V3_FACTORY, uniPools);

        tremor.dominoeFlashLoans(assets, amounts, balancerAssets, uniPools);
    }

    function simulateAaveAndUniswapFlashLoanFees(
        address[] memory assets,
        uint256[] memory amounts,
        uint256 aavePremium,
        address uniV3Factory,
        bytes[] memory uniPools
    ) internal {
        // simulating aave flash-loan fees, which should come from flash-loan profits
        for (uint256 i = 0; i < assets.length; i++) {
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
