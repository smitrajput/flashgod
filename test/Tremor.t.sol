// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {Tremor} from "../src/Tremor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TremorTest is Test {
    Tremor public tremor;
    event Debug(string message, bytes data);

    function setUp() public {
        tremor = new Tremor();
        vm.label(0x794A61358D6845594C8fcCD7fc5086eA5cC6243D, "AAVE_POOL");
    }

    // function test_callFlashLoan() public {
    //     // Approve POOL to spend borrowed amounts + 0.05% fee
    //     address[] memory assets = new address[](5);
    //     assets[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH
    //     assets[1] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; // WBTC  
    //     assets[2] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC
    //     assets[3] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT
    //     assets[4] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI

    //     uint256[] memory amounts = new uint256[](5);
    //     amounts[0] = 6_900 * 1e18;         // WETH
    //     amounts[1] = 440 * 1e8;            // WBTC
    //     amounts[2] = 20_000_000 * 1e6;     // USDC 
    //     amounts[3] = 20_000_000 * 1e6;     // USDT
    //     amounts[4] = 20_000_000 * 1e18;    // DAI

    //     address pool = 0x794A61358D6845594C8fcCD7fc5086eA5cC6243D;

    //     // Calculate amounts including 0.05% fee
    //     for(uint i = 0; i < assets.length; i++) {
    //         uint256 amountWithFee = amounts[i] + ((amounts[i] * 5) / 10000); // 0.05% fee
    //         vm.prank(address(tremor));
    //         IERC20(assets[i]).approve(pool, amountWithFee);
    //     }

    //     // Mint fee amounts to Tremor contract to cover the 0.05% premium
    //     for(uint i = 0; i < assets.length; i++) {
    //         uint256 fee = (amounts[i] * 5) / 10000; // 0.05% fee
    //         deal(assets[i], address(tremor), fee);
    //     }

    //     // Add tracing
    //     vm.recordLogs();
        
    //     try tremor.callFlashLoan() {
    //         console.log("Flash loan succeeded");
    //     } catch (bytes memory err) {
    //         console.log("Flash loan failed");
    //         console.logBytes(err);
            
    //         // Get the logs
    //         Vm.Log[] memory entries = vm.getRecordedLogs();
    //         for (uint i = 0; i < entries.length; i++) {
    //             console.log("Log", i);
    //             console.logBytes32(entries[i].topics[0]);
    //             console.logBytes(entries[i].data);
    //         }
    //     }
    // }

    function test_callSingleFlashLoan() public {
        address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        uint256 amount = 1 * 1e18; // 1 WETH
        address pool = 0x794A61358D6845594C8fcCD7fc5086eA5cC6243D;
        
        // Log initial state
        console.log("WETH balance before:", IERC20(weth).balanceOf(address(tremor)));
        
        // Approve POOL to spend borrowed amount + 0.05% fee
        uint256 amountWithFee = amount + ((amount * 5) / 10000);
        console.log("Amount with fee:", amountWithFee);
        
        vm.prank(address(tremor));
        IERC20(weth).approve(pool, amountWithFee);
        console.log("Approved amount:", IERC20(weth).allowance(address(tremor), pool));
        
        // Mint fee amount to Tremor contract
        uint256 fee = (amount * 5) / 10000;
        deal(weth, address(tremor), fee);
        console.log("Fee minted:", fee);
        console.log("WETH balance after fee mint:", IERC20(weth).balanceOf(address(tremor)));
        
        vm.recordLogs();
        
        try tremor.callSingleFlashLoan(weth, amount) {
            console.log("Flash loan succeeded");
        } catch (bytes memory err) {
            console.log("Flash loan failed");
            console.logBytes(err);
            
            Vm.Log[] memory entries = vm.getRecordedLogs();
            for (uint i = 0; i < entries.length; i++) {
                emit Debug("Log entry", entries[i].data);
            }
            
            // Try to decode the error if it's a revert string
            if (err.length > 4) {
                bytes4 selector = bytes4(err);
                if (selector == 0x08c379a0) { // Error(string)
                    bytes memory data = new bytes(err.length - 4);
                    for (uint i = 4; i < err.length; i++) {
                        data[i-4] = err[i];
                    }
                    string memory reason = abi.decode(data, (string));
                    console.log("Revert reason:", reason);
                }
            }
        }
    }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
