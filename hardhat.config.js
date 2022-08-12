require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");

const dotenv = require("dotenv");
dotenv.config();

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  for (const account of accounts) {
    console.log(account.address);
  }
});


module.exports = {
  defaultNetwork:"hardhat",
  gasReporter: {
    currency: 'USD',
    gasPriceApi: 'https://api.bscscan.com/api?module=proxy&action=eth_gasPrice'
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    mumbai: {
      url: process.env.MUMBAI_TEST_NET_API_KEY,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
    matic: {
      url: process.env.MATIC_MAIN_NET_API_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
    bscMain: {
      url: process.env.BSC_MAIN_NET_API_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
    bscTest: {
      url: process.env.BSC_TEST_NET_API_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
    fork: {
      url: "http://localhost:8545",
    },
    hardhat: {
      forking: {
        url: process.env.BSC_MAIN_NET_API_URL,
      }
    },
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY,
  },
  solidity: {
    compilers: [
      {
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
        version: "0.5.16",
      },
      {
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
        version: "0.8.0",
      },
      {
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
        version: "0.8.1",
      },
      {
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
        version: "0.8.13",
      },
      {
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
        version: "0.6.12",
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test/Mainnet Fork",
    cache: "./cache",
    artifacts: "./artifacts"
  },
};
