require("@nomicfoundation/hardhat-toolbox")
require("hardhat-deploy")
require("dotenv").config()

/** @type import('hardhat/config').HardhatUserConfig */

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x"
const BAOBAB_RPC_URL =
    process.env.BAOBAB_RPC_URL || "https://api.baobab.klaytn.net:8651"

module.exports = {
    networks: {
        hardhat: {
            chainId: 31337,
        },
        localhost: {
            chainId: 31337,
        },
        baobab: {
            url: BAOBAB_RPC_URL,
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            //accounts: {
            //     mnemonic: MNEMONIC,
            // },
            saveDeployments: true,
            chainId: 1001,
        },
    },
    solidity: "0.8.17",
    namedAccounts: {
        deployer: 0,
    },
    gasReporter: {
        enabled: true,
        currency: "USD",
        // outputFile: "gas-report.txt",
        noColors: true,
        // coinmarketcap: COINMARKETCAP_API_KEY,
    },
}
