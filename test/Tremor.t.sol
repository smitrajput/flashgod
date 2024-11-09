// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console, Vm} from "forge-std/Test.sol";
import {Tremor} from "../src/Tremor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {DeployAaveV3} from "../script/DeployAaveV3.s.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol"; // Add this import

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

contract TremorTest is Test {
    Tremor public tremor;
    IPool public pool;
    DeployAaveV3 public deployer;

    address public LINK;
    address public aLINK;
    IERC20 public linkToken;

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));
        vm.selectFork(forkId);

        // Deploy AAVE V3
        // deployer = new DeployAaveV3();
        // deployer.run();

        // Get the deployed pool address from the deployer
        // pool = IPool(deployer.getPool());
        pool = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

        // FIND MAX FLASH-LOANABLE AMOUNTS OF ALL FLASHLOANABLE TOKENS

        // Get the LINK token address from the deployer instead of using a constant
        // LINK = deployer.linkToken();
        // LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
        // WETH: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 -14784450271841927598027 = 14784
        // aWETH: 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8
        // WBTC: 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f - 330421334539 = 3300
        // aWBTC: 0x078f358208685046a11C85e8ad32895DED33A249
        // weETH: 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe
        // aweETH: 0x8437d7C167dFB82ED4Cb79CD44B7a32A1dd95c77
        LINK = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
        aLINK = 0x8437d7C167dFB82ED4Cb79CD44B7a32A1dd95c77;
        linkToken = IERC20(LINK);
        console.log("Flash-loanable:", IERC20(LINK).balanceOf(aLINK));

        // Deploy Tremor
        // tremor = new Tremor(address(deployer.getAddressesProvider()), address(pool));
        tremor = new Tremor(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb, address(pool));

        // No need for vm.etch since we're using the already deployed MockERC20

        // Set up labels for better trace outputs
        vm.label(address(pool), "AAVE_POOL");
        vm.label(LINK, "LINK");
    }

    function test_callSingleFlashLoan() public {
        uint256 amount = 3000 * 1e8; // 1000 LINK tokens
        // uint256 amount = 100239444798603839364697;

        // Supply some LINK to the pool first
        // deal(LINK, address(this), amount * 2);
        // IERC20(LINK).approve(address(pool), type(uint256).max);
        // pool.supply(LINK, amount * 2, address(this), 0);

        // Get the aToken address for LINK
        DataTypes.ReserveData memory reserveData = pool.getReserveData(LINK);
        address aTokenAddress = reserveData.aTokenAddress;
        // Get total supply of aTokens which represents total LINK in pool
        uint256 totalLinkInPool = IERC20(aTokenAddress).totalSupply();
        console.log("Total LINK in pool:", totalLinkInPool);

        // Fund Tremor contract with fee amount (0.05%)
        // uint256 fee = (amount * 5) / 100;
        uint256 fee = (amount * 5) / 10000;
        deal(LINK, address(tremor), fee);

        console.log("FLASHLOAN_PREMIUM_TO_PROTOCOL:", pool.FLASHLOAN_PREMIUM_TO_PROTOCOL());
        console.log("FLASHLOAN_PREMIUM_TOTAL:", pool.FLASHLOAN_PREMIUM_TOTAL());

        // // Get the pool configurator address
        // address poolConfigurator = IPoolAddressesProvider(deployer.getAddressesProvider()).getPoolConfigurator();
        // // Impersonate pool configurator to update flash loan premiums
        // vm.prank(poolConfigurator);
        // pool.updateFlashloanPremiums(5, 5);

        // Approve pool to spend tokens
        // IERC20(LINK).approve(address(pool), type(uint256).max);

        vm.recordLogs();

        try tremor.callSingleFlashLoan(LINK, amount) {
            console.log("Flash loan succeeded");
            console.log("Final LINK balance:", IERC20(LINK).balanceOf(address(tremor)));
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
