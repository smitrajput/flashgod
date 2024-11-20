// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Tremor} from "../src/Tremor.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {DeployAaveV3} from "../script/DeployAaveV3.s.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol"; // Add this import
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {Pair1Flash} from "../src/Pair1Flash.sol";
import {Pair2Flash} from "../src/Pair2Flash.sol";
import {Test, console, Vm} from "forge-std/Test.sol";

contract TremorTest is Test {
    Tremor public tremor;
    IPool public pool;
    ISwapRouter public swapRouter;
    Pair1Flash public pair1Flash;
    Pair2Flash public pair2Flash;

    address public constant VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    // Arbitrum
    address public constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address public constant RDNT = 0x3082CC23568eA640225c2467653dB90e9250AaA0;
    address public constant WE_ETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address public constant WSTETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant RETH = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8;
    address public constant LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public constant GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address public constant UNI_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public constant BAL_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));
        vm.selectFork(forkId);

        swapRouter = ISwapRouter(SWAP_ROUTER);

        // Get the deployed pool address from the deployer
        // pool = IPool(deployer.getPool());
        pool = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

        // Deploy Tremor
        // tremor = new Tremor(address(deployer.getAddressesProvider()), address(pool));
        tremor = new Tremor(
            0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb, address(pool), UNI_V3_FACTORY, SWAP_ROUTER, BAL_VAULT, WETH
        );

        // Set up labels for better trace outputs
        vm.label(address(pool), "AAVE_POOL");
    }

    function test_dominoeFlashLoans() public {
        console.log("FLASHLOAN_PREMIUM_TO_PROTOCOL:", pool.FLASHLOAN_PREMIUM_TO_PROTOCOL());
        console.log("FLASHLOAN_PREMIUM_TOTAL:", pool.FLASHLOAN_PREMIUM_TOTAL());

        address[] memory assets = new address[](8);
        assets[0] = WETH;
        assets[1] = WBTC;
        assets[2] = USDC;
        assets[3] = WE_ETH;
        assets[4] = WSTETH;
        assets[5] = ARB;
        assets[6] = LINK;
        assets[7] = RETH;
        uint256[] memory amounts = new uint256[](8);

        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            if (assets[i] == USDC) {
                amounts[i] = maxFlashloanable - 50_000_000;
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            // console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        // Fund Tremor contract with fee amount (0.05%) for each asset
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 fee = (amounts[i] * 10) / 10000; // 0.05%
            deal(assets[i], address(tremor), fee);
        }

        address[] memory balancerAssets = new address[](4);
        balancerAssets[0] = WBTC;
        balancerAssets[1] = RDNT;
        balancerAssets[2] = WETH;
        balancerAssets[3] = USDC;

        bytes[] memory uniPools = new bytes[](4);
        uniPools[0] = abi.encode(WBTC, WETH, 500);
        uniPools[1] = abi.encode(WETH, USDC, 500);
        uniPools[2] = abi.encode(WETH, GMX, 10000);
        uniPools[3] = abi.encode(WBTC, USDT, 500);

        vm.recordLogs();

        try tremor.dominoeFlashLoans(assets, amounts, balancerAssets, uniPools) {
            console.log("Flash loan succeeded");
        } catch (bytes memory err) {
            console.log("Flash loan failed");
            console.logBytes(err);

            Vm.Log[] memory entries = vm.getRecordedLogs();
            for (uint256 i = 0; i < entries.length; i++) {
                emit Debug("Log entry", entries[i].data);
            }

            // Try to decode the error if it's a revert string
            if (err.length > 4) {
                bytes4 selector = bytes4(err);
                if (selector == 0x08c379a0) {
                    bytes memory data = new bytes(err.length - 4);
                    for (uint256 i = 4; i < err.length; i++) {
                        data[i - 4] = err[i];
                    }
                    string memory reason = abi.decode(data, (string));
                    console.log("Revert reason:", reason);
                }
            }
        }
    }

    event Debug(string message, bytes data);
}
