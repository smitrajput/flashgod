// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.10;

// import {Script} from "forge-std/Script.sol";
// import {PoolAddressesProvider} from "@aave/core-v3/contracts/protocol/configuration/PoolAddressesProvider.sol";
// import {PoolAddressesProviderRegistry} from
//     "@aave/core-v3/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol";
// import {AaveProtocolDataProvider} from "@aave/core-v3/contracts/misc/AaveProtocolDataProvider.sol";
// import {Pool} from "@aave/core-v3/contracts/protocol/pool/Pool.sol";
// import {ACLManager} from "@aave/core-v3/contracts/protocol/configuration/ACLManager.sol";
// import {PriceOracleSentinel} from "@aave/core-v3/contracts/protocol/configuration/PriceOracleSentinel.sol";
// import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
// import {ISequencerOracle} from "@aave/core-v3/contracts/interfaces/ISequencerOracle.sol";
// import {AToken} from "@aave/core-v3/contracts/protocol/tokenization/AToken.sol";
// import {StableDebtToken} from "@aave/core-v3/contracts/protocol/tokenization/StableDebtToken.sol";
// import {VariableDebtToken} from "@aave/core-v3/contracts/protocol/tokenization/VariableDebtToken.sol";
// import {DefaultReserveInterestRateStrategy} from
//     "@aave/core-v3/contracts/protocol/pool/DefaultReserveInterestRateStrategy.sol";
// import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
// import {IPoolConfigurator} from "@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol";
// import {PoolConfigurator} from "@aave/core-v3/contracts/protocol/pool/PoolConfigurator.sol";
// import {ConfiguratorInputTypes} from "@aave/core-v3/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol";
// import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract DeployAaveV3 is Script {
//     Pool public POOL;
//     PoolAddressesProvider public ADDRESSES_PROVIDER;
//     address public linkToken;
//     uint256 public linkInitialPrice;

//     function run() external {
//         // Get the address that will be used for broadcasting transactions
//         address deployer = vm.envAddress("DEPLOYER_ADDRESS");

//         // Deploy mock LINK instead of reading from env
//         MockERC20 mockLink = new MockERC20("Chainlink", "LINK");
//         linkToken = address(mockLink);
//         linkInitialPrice = vm.envUint("LINK_INITIAL_PRICE");

//         vm.startBroadcast(deployer);

//         // 1. Deploy PoolAddressesProviderRegistry
//         PoolAddressesProviderRegistry registry = new PoolAddressesProviderRegistry(
//             deployer // Use deployer address instead of address(this)
//         );

//         // 2. Deploy PoolAddressesProvider
//         PoolAddressesProvider provider = new PoolAddressesProvider(
//             "AAVE V3 Market",
//             deployer // Use deployer address instead of address(this)
//         );

//         // 3. Register the provider in the registry
//         registry.registerAddressesProvider(address(provider), 1);

//         // Add this line before ACLManager deployment
//         provider.setACLAdmin(deployer);

//         // 4. Deploy ACLManager
//         ACLManager aclManager = new ACLManager(provider);
//         provider.setACLManager(address(aclManager));

//         // 5. Deploy Pool Implementation
//         POOL = new Pool(provider);

//         // 6. Set Pool implementation in provider
//         provider.setPoolImpl(address(POOL));

//         // 7. Deploy Protocol Data Provider
//         AaveProtocolDataProvider dataProvider = new AaveProtocolDataProvider(provider);

//         // 8. Setup initial ACL
//         aclManager.addPoolAdmin(deployer);
//         aclManager.addEmergencyAdmin(deployer);
//         aclManager.addRiskAdmin(deployer);
//         aclManager.addAssetListingAdmin(deployer);

//         // 9. Deploy price oracle sentinel with required parameters
//         SimplePriceOracle oracle = new SimplePriceOracle(provider, ISequencerOracle(address(0)), 3600);
//         provider.setPriceOracle(address(oracle));

//         // 10. Get the deployed pool instance
//         POOL = Pool(provider.getPool());
//         ADDRESSES_PROVIDER = provider;

//         // Deploy tokens implementations
//         AToken aTokenImpl = new AToken(IPool(address(POOL)));

//         StableDebtToken stableDebtTokenImpl = new StableDebtToken(IPool(address(POOL)));

//         VariableDebtToken variableDebtTokenImpl = new VariableDebtToken(IPool(address(POOL)));

//         // Deploy interest rate strategy
//         // Parameters explanation:
//         // optimalUsageRatio: 80%
//         // baseVariableBorrowRate: 0%
//         // variableRateSlope1: 4%
//         // variableRateSlope2: 75%
//         // stableRateSlope1: 2%
//         // stableRateSlope2: 75%
//         // baseStableRateOffset: 1%
//         DefaultReserveInterestRateStrategy interestRateStrategy = new DefaultReserveInterestRateStrategy(
//             provider,
//             80_00, // optimal usage ratio (in percentage)
//             0, // base variable borrow rate
//             4_00, // variable rate slope1
//             75_00, // variable rate slope2
//             2_00, // stable rate slope1
//             75_00, // stable rate slope2
//             1_00, // base stable rate offset
//             0, // optimalStableToTotalDebtRatio
//             0 // maxExcessStableToTotalDebtRatio
//         );

//         // Deploy Pool Configurator implementation FIRST
//         PoolConfigurator configuratorImpl = new PoolConfigurator();
//         provider.setPoolConfiguratorImpl(address(configuratorImpl));

//         // Add deployer as pool configurator admin
//         aclManager.addPoolAdmin(deployer);

//         // Get the pool configurator
//         IPoolConfigurator configurator = IPoolConfigurator(ADDRESSES_PROVIDER.getPoolConfigurator());

//         ConfiguratorInputTypes.InitReserveInput[] memory inputs = new ConfiguratorInputTypes.InitReserveInput[](1);
//         inputs[0] = ConfiguratorInputTypes.InitReserveInput({
//             aTokenImpl: address(aTokenImpl),
//             stableDebtTokenImpl: address(stableDebtTokenImpl),
//             variableDebtTokenImpl: address(variableDebtTokenImpl),
//             underlyingAssetDecimals: IERC20Metadata(address(linkToken)).decimals(),
//             interestRateStrategyAddress: address(interestRateStrategy),
//             underlyingAsset: address(linkToken),
//             treasury: address(0),
//             incentivesController: address(0),
//             aTokenName: "Aave LINK",
//             aTokenSymbol: "aLINK",
//             variableDebtTokenName: "Aave Variable Debt LINK",
//             variableDebtTokenSymbol: "variableDebtLINK",
//             stableDebtTokenName: "Aave Stable Debt LINK",
//             stableDebtTokenSymbol: "stableDebtLINK",
//             params: bytes("")
//         });
//         // Initialize reserve through the configurator instead of directly through the pool
//         configurator.initReserves(inputs);

//         // Configure the reserve
//         configurator.setReserveActive(address(linkToken), true);
//         configurator.setReserveBorrowing(address(linkToken), true);
//         configurator.setReserveStableRateBorrowing(address(linkToken), true);
//         configurator.configureReserveAsCollateral(
//             address(linkToken),
//             75_00, // LTV (75%)
//             80_00, // Liquidation Threshold (80%)
//             105_00 // Liquidation Bonus (5%)
//         );
//         configurator.setReserveFactor(address(linkToken), 20_00); // 20%
//         configurator.setReserveFlashLoaning(address(linkToken), true);

//         // If you're using a price oracle, set the price
//         oracle.setAssetPrice(address(linkToken), linkInitialPrice);

//         vm.stopBroadcast();
//     }

//     function getPool() external view returns (address) {
//         return address(POOL);
//     }

//     function getAddressesProvider() external view returns (address) {
//         return address(ADDRESSES_PROVIDER);
//     }
// }

// // Update SimplePriceOracle to properly inherit
// contract SimplePriceOracle is PriceOracleSentinel {
//     mapping(address => uint256) prices;

//     constructor(IPoolAddressesProvider provider, ISequencerOracle oracle, uint256 gracePeriod)
//         PriceOracleSentinel(provider, oracle, gracePeriod)
//     {}

//     function setAssetPrice(address asset, uint256 price) external {
//         prices[asset] = price;
//     }

//     function getAssetPrice(address asset) external view returns (uint256) {
//         return prices[asset];
//     }
// }

// contract MockERC20 is ERC20 {
//     constructor(string memory name, string memory symbol) ERC20(name, symbol) {
//         _mint(msg.sender, 1000000 * 10 ** decimals()); // Mint some initial supply
//     }
// }
