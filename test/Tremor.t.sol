// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console, Vm} from "forge-std/Test.sol";
import {Tremor} from "../src/Tremor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {DeployAaveV3} from "../script/DeployAaveV3.s.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol"; // Add this import

contract TremorTest is Test {
    Tremor public tremor;
    IPool public pool;

    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address public constant WE_ETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant WSTETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address public constant USDT = 0xfD086BC7cD4c4ca33BD5C38ec837347e8A75A05d;
    address public constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address public constant LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address public constant RETH = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8;

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));
        vm.selectFork(forkId);

        // Get the deployed pool address from the deployer
        // pool = IPool(deployer.getPool());
        pool = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

        // Deploy Tremor
        // tremor = new Tremor(address(deployer.getAddressesProvider()), address(pool));
        tremor = new Tremor(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb, address(pool));

        // Set up labels for better trace outputs
        vm.label(address(pool), "AAVE_POOL");
    }

    function test_callFlashLoan() public {
        console.log("FLASHLOAN_PREMIUM_TO_PROTOCOL:", pool.FLASHLOAN_PREMIUM_TO_PROTOCOL());
        console.log("FLASHLOAN_PREMIUM_TOTAL:", pool.FLASHLOAN_PREMIUM_TOTAL());

        address[] memory assets = new address[](8);
        assets[0] = WETH; // WETH on Arbitrum
        assets[1] = WBTC; // WBTC on Arbitrum
        assets[2] = USDC; // weETH on Arbitrum
        assets[3] = WE_ETH; // USDC on Arbitrum
        assets[4] = WSTETH; // USDT on Arbitrum
        assets[5] = ARB; // DAI on Arbitrum
        assets[6] = LINK; // LINK on Arbitrum
        assets[7] = RETH; // rETH on Arbitrum
        uint256[] memory amounts = new uint256[](8);

        uint256 maxFlashloanable;
        for (uint256 i = 0; i < assets.length; i++) {
            maxFlashloanable = IERC20(assets[i]).balanceOf((pool.getReserveData(assets[i])).aTokenAddress);
            // amounts[i] = assets[i] == USDC ? maxFlashloanable - 6_000_000 : maxFlashloanable - 1;
            if (assets[i] == USDC) {
                amounts[i] = maxFlashloanable - 50_000_000;
            } else {
                amounts[i] = maxFlashloanable - (10 ** IERC20Metadata(assets[i]).decimals());
            }
            console.log("Flash-loanable:", i, maxFlashloanable / (10 ** IERC20Metadata(assets[i]).decimals()));
        }

        // Fund Tremor contract with fee amount (0.05%) for each asset
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 fee = (amounts[i] * 10) / 10000; // 0.05%
            deal(assets[i], address(tremor), fee);
        }

        vm.recordLogs();

        try tremor.callFlashLoan(assets, amounts) {
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

// MAX FLASH-LOANABLE AMOUNTS OF ALL FLASHLOANABLE TOKENS //////////////////////////////
// WETH: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 -14784450271841927598027 = 14784
// aWETH: 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8
// WBTC: 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f - 330421334539 = 3304
// aWBTC: 0x078f358208685046a11C85e8ad32895DED33A249
// weETH: 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe - 81108159289949938640504 = 81108
// aweETH: 0x8437d7C167dFB82ED4Cb79CD44B7a32A1dd95c77
// USDC: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 - 15171759807546 = 15171759
// aUSDC: 0x724dc807b04555b71ed48a6896b6F41593b8C637
// wstETH: 0x5979D7b546E38E414F7E9822514be443A4800529 - 35759499332743020693286 = 35759
// awstETH: 0x513c7E3a9c69cA3e22550eF58AC1C0088e918FFf
// USDT: 0xFd086bC7CD4C4Ca33BD5c38ec837347E8a75a05D - 7323203490740 = 7323203
// aUSDT: 0x6ab707Aca953eDAeFBc4fD23bA73294241490620
// ARB: 0x912CE59144191C1204E64559FE8253a0e49E6548 - 54715222330715085671344780 = 54715222
// aARB: 0x6533afac2E7BCCB20dca161449A13A32D391fb00
// LINK: 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4 - 1818953354647390052558848 = 1818953
// aLINK: 0x191c10Aa4AF7C30e871E70C95dB0E4eb77237530
// rETH: 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8 - 3071942616877375984586 = 3071
// arETH: 0x8Eb270e296023E9D92081fdF967dDd7878724424

// // Get the pool configurator address
// address poolConfigurator = IPoolAddressesProvider(deployer.getAddressesProvider()).getPoolConfigurator();
// // Impersonate pool configurator to update flash loan premiums
// vm.prank(poolConfigurator);
// pool.updateFlashloanPremiums(5, 5);

// contract MockERC20 {
//     mapping(address => uint256) public balanceOf;
//     mapping(address => mapping(address => uint256)) public allowance;

//     function approve(address spender, uint256 amount) public returns (bool) {
//         allowance[msg.sender][spender] = amount;
//         return true;
//     }

//     function transfer(address to, uint256 amount) public returns (bool) {
//         balanceOf[msg.sender] -= amount;
//         balanceOf[to] += amount;
//         return true;
//     }

//     function transferFrom(address from, address to, uint256 amount) public returns (bool) {
//         require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
//         allowance[from][msg.sender] -= amount;
//         balanceOf[from] -= amount;
//         balanceOf[to] += amount;
//         return true;
//     }
// }
