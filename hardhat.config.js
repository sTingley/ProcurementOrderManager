const { task } = require("hardhat/config");
require('@nomiclabs/hardhat-ethers');
//require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();
require('solidity-coverage');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-abi-exporter');
require('hardhat-gas-reporter');
require('dotenv').config();
require('solidity-docgen');
require('hardhat-contract-sizer');

const { PRIVATE_KEY, ALCHEMY_URL } = process.env;

const lazyImport = async (module) => {
  return import(module);
};

//We could pass contract addresses to this task if we wanted the ability to deploy subset(s) of Solidity files
task('deploy-contracts', 'Deploys contracts')
  .setAction(async (taskArgs) => {
    console.log("deploying contracts");
    const { deployContracts } = await lazyImport('./scripts/deploy.js');
    await deployContracts({})
  })

module.exports = {
  solidity: "0.8.20",

  settings: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  gasReporter: {
    currency: 'USD',
    token: 'MATIC',
    coinmarketcap: '235cc39a-57af-4b76-bd11-f4e2fa32b2c5',
    gasPriceAPI: 'https://api.polygonscan.com/api?module=proxy&action=eth_gasPrice'
  },
  networks: {
    localhost: {
      url: 'http://localhost:8545',
      chainId: 31337
    },
    hardhat: {},
    PolygonMumbai: {
      url: ALCHEMY_URL,
      accounts: [PRIVATE_KEY],
      gas: 2100000,
      chainId: 80001
    }
    //,
    // PolygonMainnet: {
    //   url: ALCHEMY_URL,
    //   accounts: [PRIVATE_KEY],
    //   gas: 2100000,
    //   chainId: 137
    // }
  },
  docgen: {
    pages: 'items'
  },
  abiExporter: {
    runOnCompile: true,
    clear: true,
    only: ['contracts/*']
  }
};
