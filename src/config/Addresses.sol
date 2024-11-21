// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

library Addresses {
    struct ProviderAddresses {
        address UNI_V3_FACTORY;
        address BAL_VAULT;
        address SWAP_ROUTER;
        address ADDRESSES_PROVIDER;
    }

    struct EthereumAddresses {
        ProviderAddresses provider;
        address WETH;
        address USDC;
        address WBTC;
        address WE_ETH;
        address WSTETH;
        address RETH;
        address LINK;
        address USDT;
        address CB_BTC;
        address T_BTC;
        address USDS;
        address AAVE;
        address BAL;
    }

    struct ArbitrumAddresses {
        ProviderAddresses provider;
        address WETH;
        address USDC;
        address WBTC;
        address RDNT;
        address WE_ETH;
        address WSTETH;
        address ARB;
        address RETH;
        address LINK;
        address USDT;
        address GMX;
    }

    struct OptimismAddresses {
        ProviderAddresses provider;
        address WETH;
        address USDC;
        address WBTC;
        address WSTETH;
        address RETH;
        address LINK;
        address USDT;
        address OP;
    }

    struct PolygonAddresses {
        ProviderAddresses provider;
        address WETH;
        address USDC;
        address WBTC;
        address WSTETH;
        address LINK;
        address USDT;
        address WMATIC;
        address MATICX;
        address TEL;
        address USDCe;
    }

    struct BaseAddresses {
        ProviderAddresses provider;
        address WETH;
        address USDC;
        address WSTETH;
        address CB_BTC;
        address WE_ETH;
        address CB_ETH;
        address DEGEN;
        address RDNT;
        address RETH;
    }

    struct AvalancheAddresses {
        ProviderAddresses provider;
        address BTC_b;
        address WAVAX;
        address USDC;
        address sAVAX;
        address USDT;
        address WETH_e;
        address LINK_e;
        address ggAVAX;
    }

    struct BscAddresses {
        ProviderAddresses provider;
        address BTCB;
        address WBNB;
        address USDC;
        address USDT;
        address ETH;
        address FDUSD;
        address WSTETH;
    }

    function ethereumAddresses() internal pure returns (EthereumAddresses memory) {
        // Sources:
        // Uniswap: https://docs.uniswap.org/contracts/v3/reference/deployments
        // Balancer: https://docs.balancer.fi/reference/contracts/deployment-addresses/mainnet.html
        // Aave: https://docs.aave.com/developers/deployed-contracts/v3-mainnet/ethereum-mainnet
        ProviderAddresses memory provider = ProviderAddresses({
            UNI_V3_FACTORY: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            BAL_VAULT: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            SWAP_ROUTER: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
            ADDRESSES_PROVIDER: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e
        });

        return EthereumAddresses({
            provider: provider,
            T_BTC: 0x18084fbA666a33d37592fA2633fD49a74DD93a88, // Smallest
            WBTC: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            LINK: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            AAVE: 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
            WSTETH: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
            USDC: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            RETH: 0xae78736Cd615f374D3085123A210448E74Fc6393,
            BAL: 0xba100000625a3754423978a60c9317c58a424e3D,
            WETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            WE_ETH: 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee,
            CB_BTC: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf,
            USDT: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
            USDS: 0xdC035D45d973E3EC169d2276DDab16f1e407384F // Largest
        });
    }

    function arbitrumAddresses() internal pure returns (ArbitrumAddresses memory) {
        // Sources:
        // Uniswap: https://docs.uniswap.org/contracts/v3/reference/deployments
        // Balancer: https://docs.balancer.fi/reference/contracts/deployment-addresses/arbitrum.html
        // Aave: https://docs.aave.com/developers/deployed-contracts/v3-mainnet/arbitrum
        ProviderAddresses memory provider = ProviderAddresses({
            UNI_V3_FACTORY: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            BAL_VAULT: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            SWAP_ROUTER: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
            ADDRESSES_PROVIDER: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
        });

        return ArbitrumAddresses({
            provider: provider,
            WETH: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            USDC: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            WBTC: 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,
            RDNT: 0x3082CC23568eA640225c2467653dB90e9250AaA0,
            WE_ETH: 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe,
            WSTETH: 0x5979D7b546E38E414F7E9822514be443A4800529,
            ARB: 0x912CE59144191C1204E64559FE8253a0e49E6548,
            RETH: 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8,
            LINK: 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,
            USDT: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9,
            GMX: 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a
        });
    }

    function optimismAddresses() internal pure returns (OptimismAddresses memory) {
        // Sources:
        // Uniswap: https://docs.uniswap.org/contracts/v3/reference/deployments
        // Balancer: https://docs.balancer.fi/reference/contracts/deployment-addresses/optimism.html
        // Aave: https://docs.aave.com/developers/deployed-contracts/v3-mainnet/optimism
        ProviderAddresses memory provider = ProviderAddresses({
            UNI_V3_FACTORY: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            BAL_VAULT: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            SWAP_ROUTER: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
            ADDRESSES_PROVIDER: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
        });

        return OptimismAddresses({
            provider: provider,
            USDC: 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85,
            WSTETH: 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb,
            LINK: 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6,
            WETH: 0x4200000000000000000000000000000000000006,
            OP: 0x4200000000000000000000000000000000000042,
            WBTC: 0x68f180fcCe6836688e9084f035309E29Bf0A2095,
            USDT: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58,
            RETH: 0x9Bcef72be871e61ED4fBbc7630889beE758eb81D
        });
    }

    function polygonAddresses() internal pure returns (PolygonAddresses memory) {
        // Sources:
        // Uniswap: https://docs.uniswap.org/contracts/v3/reference/deployments
        // Balancer: https://docs.balancer.fi/reference/contracts/deployment-addresses/polygon.html
        // Aave: https://docs.aave.com/developers/deployed-contracts/v3-mainnet/polygon
        ProviderAddresses memory provider = ProviderAddresses({
            UNI_V3_FACTORY: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            BAL_VAULT: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            SWAP_ROUTER: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
            ADDRESSES_PROVIDER: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
        });

        return PolygonAddresses({
            provider: provider,
            WSTETH: 0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD,
            WMATIC: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
            WBTC: 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6,
            USDCe: 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            USDC: 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359,
            LINK: 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39,
            WETH: 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            USDT: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
            TEL: 0xdF7837DE1F2Fa4631D716CF2502f8b230F1dcc32,
            MATICX: 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6
        });
    }

    function baseAddresses() internal pure returns (BaseAddresses memory) {
        // Sources:
        // Base: https://docs.base.org/base-contracts
        ProviderAddresses memory provider = ProviderAddresses({
            UNI_V3_FACTORY: 0x33128a8fC17869897dcE68Ed026d694621f6FDfD,
            BAL_VAULT: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            SWAP_ROUTER: 0x2626664c2603336E57B271c5C0b26F421741e481,
            ADDRESSES_PROVIDER: 0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D
        });

        return BaseAddresses({
            provider: provider,
            WETH: 0x4200000000000000000000000000000000000006, // 4.76e36 (smallest)
            WE_ETH: 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A, // 2.17e40
            CB_ETH: 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22, // 1.93e41
            DEGEN: 0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed, // 3.57e41
            USDC: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // 5.94e41
            RETH: 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c, // 8.29e41
            WSTETH: 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452, // 8.77e41
            CB_BTC: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf, // 9.19e41
            RDNT: 0xd722E55C1d9D9fA0021A5215Cbb904b92B3dC5d4 // 9.74e41 (largest)
        });
    }

    function avalancheAddresses() internal pure returns (AvalancheAddresses memory) {
        ProviderAddresses memory provider = ProviderAddresses({
            UNI_V3_FACTORY: 0x740b1c1de25031C31FF4fC9A62f554A55cdC1baD, // Uniswap v3 factory on Avalanche
            BAL_VAULT: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            SWAP_ROUTER: 0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE, // Uniswap v3 router on Avalanche
            ADDRESSES_PROVIDER: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
        });

        return AvalancheAddresses({
            provider: provider,
            BTC_b: 0x152b9d0FdC40C096757F570A51E494bd4b943E50, // 9.66e43 (smallest)
            sAVAX: 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE, // 1.95e44
            WETH_e: 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB, // 3.33e44
            LINK_e: 0x5947BB275c521040051D82396192181b413227A3, // 3.99e44
            USDT: 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7, // 6.80e44
            ggAVAX: 0xA25EaF2906FA1a3a13EdAc9B9657108Af7B703e3, // 7.31e44
            WAVAX: 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7, // 8.10e44
            USDC: 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E // 8.39e44 (largest)
        });
    }

    function bscAddresses() internal pure returns (BscAddresses memory) {
        // Sources:
        // BSC: https://docs.bscscan.com/
        ProviderAddresses memory provider = ProviderAddresses({
            UNI_V3_FACTORY: 0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7,
            BAL_VAULT: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            SWAP_ROUTER: 0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2,
            ADDRESSES_PROVIDER: 0xff75B6da14FfbbfD355Daf7a2731456b3562Ba6D
        });

        return BscAddresses({
            provider: provider,
            ETH: 0x2170Ed0880ac9A755fd29B2688956BD959F933F8, // 1.51e44 (smallest)
            WSTETH: 0x26c5e01524d2E6280A48F2c50fF6De7e52E9611C, // 1.78e44
            USDT: 0x55d398326f99059fF775485246999027B3197955, // 3.86e44
            BTCB: 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c, // 5.09e44
            USDC: 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, // 6.29e44
            WBNB: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, // 8.46e44
            FDUSD: 0xc5f0f7b66764F6ec8C8Dff7BA683102295E16409 // 8.97e44 (largest)
        });
    }
}
