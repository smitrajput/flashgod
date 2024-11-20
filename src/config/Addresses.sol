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
        address WETH; // Native wrapped token
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
    }

    struct PolygonAddresses {
        ProviderAddresses provider;
        address WETH;
        address USDC;
        address WBTC;
        address WSTETH;
        address LINK;
        address USDT;
    }

    struct BaseAddresses {
        ProviderAddresses provider;
        address WETH;
        address USDC;
        address WSTETH;
        address RETH;
        address LINK;
        address USDT;
    }

    struct ZkSyncAddresses {
        ProviderAddresses provider;
        address WETH;
        address USDC;
        address WBTC;
        address WSTETH;
        address USDT;
    }

    struct FantomAddresses {
        ProviderAddresses provider;
        address WETH;
        address USDC;
        address WBTC;
        address LINK;
        address USDT;
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
            WETH: 0x4200000000000000000000000000000000000006,
            USDC: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607,
            WBTC: 0x68f180fcCe6836688e9084f035309E29Bf0A2095,
            WSTETH: 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb,
            RETH: 0x9Bcef72be871e61ED4fBbc7630889beE758eb81D,
            LINK: 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6,
            USDT: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58
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
            WETH: 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            USDC: 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            WBTC: 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6,
            WSTETH: 0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD,
            LINK: 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39,
            USDT: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F
        });
    }

    function baseAddresses() internal pure returns (BaseAddresses memory) {
        // Sources:
        // Base: https://docs.base.org/base-contracts
        ProviderAddresses memory provider = ProviderAddresses({
            UNI_V3_FACTORY: 0x33128a8fC17869897dcE68Ed026d694621f6FDfD,
            BAL_VAULT: address(0), // Not available
            SWAP_ROUTER: 0x2626664c2603336E57B271c5C0b26F421741e481,
            ADDRESSES_PROVIDER: address(0) // Not available
        });

        return BaseAddresses({
            provider: provider,
            WETH: 0x4200000000000000000000000000000000000006,
            USDC: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            WSTETH: 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452,
            RETH: 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c,
            LINK: 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196,
            USDT: 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2
        });
    }

    function zkSyncAddresses() internal pure returns (ZkSyncAddresses memory) {
        // Sources:
        // zkSync Era Portal: https://era.zksync.io/docs/dev/building-on-zksync/useful-address.html
        ProviderAddresses memory provider = ProviderAddresses({
            UNI_V3_FACTORY: address(0), // Not available
            BAL_VAULT: address(0), // Not available
            SWAP_ROUTER: address(0), // Not available
            ADDRESSES_PROVIDER: address(0) // Not available
        });

        return ZkSyncAddresses({
            provider: provider,
            WETH: 0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91,
            USDC: 0x3355df6D4c9C3035724Fd0e3914dE96A5a83aaf4,
            WBTC: 0xBBeB516fb02a01611cBBE0453Fe3c580D7281011,
            WSTETH: 0x703b52F2b28fEbcB60E1372858AF5b18849FE867,
            USDT: 0x493257fD37EDB34451f62EDf8D2a0C418852bA4C
        });
    }

    function fantomAddresses() internal pure returns (FantomAddresses memory) {
        // Sources:
        // Fantom Foundation: https://docs.fantom.foundation/quick-start/built-on-fantom
        ProviderAddresses memory provider = ProviderAddresses({
            UNI_V3_FACTORY: address(0), // Not available
            BAL_VAULT: 0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce,
            SWAP_ROUTER: address(0), // Not available
            ADDRESSES_PROVIDER: address(0) // Not available
        });

        return FantomAddresses({
            provider: provider,
            WETH: 0x74b23882a30290451A17c44f4F05243b6b58C76d,
            USDC: 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75,
            WBTC: 0x321162Cd933E2Be498Cd2267a90534A804051b11,
            LINK: 0xb3654dc3D10Ea7645f8319668E8F54d2574FBdC8,
            USDT: 0x049d68029688eAbF473097a2fC38ef61633A3C7A
        });
    }
}
