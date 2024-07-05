require("@nomiclabs/hardhat-waffle");
require("dotenv").config();
require("@nomicfoundation/hardhat-verify");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat:{},
    mainnet: {
      url: process.env.BASE_QN_RPC,
      accounts: [process.env.DEPLOYER_PK]
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      accounts: [process.env.DEPLOYER_PK]
    }
  },
  etherscan: {
    apiKey: {
      bscTestnet: process.env.BSC_API_KEY,
      base:  process.env.BASE_API_KEY,
      // bsc:  process.env.BAC_API_KEY,
    }
  },
  solidity: "0.8.24",
};
