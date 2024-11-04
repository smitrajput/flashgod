// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Tremor is IFlashLoanReceiver {

    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
    }

    function POOL() external view returns (IPool) {
        return IPool(0x794a61358D6845594c8fCcD7fC5086eA5CC6243D);
        // return ADDRESSES_PROVIDER().getPool(/*id of pool on arbitrum*/);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        return true;
    }

    function callFlashLoan(uint256 amount) external {
        bytes memory data = abi.encode(amount);
        POOL().flashLoan(address(this), assets, amounts, premiums, initiator, data);
    }
}
