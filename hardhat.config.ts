require("dotenv").config();

import { HardhatUserConfig } from "hardhat/config";
import { privateKeys } from "./utils/wallets";

import "@nomiclabs/hardhat-waffle";
import "hardhat-typechain";
import "solidity-coverage";
import "hardhat-deploy";
import "hardhat-contract-sizer";
import "./tasks";

const INTEGRATIONTEST_TIMEOUT = 600000;

const polygonForkingConfig = {
  url: process.env.POLYGON_RPC_URL ?? "",
  blockNumber: 25004110,
};

const mainnetForkingConfig = {
  url: "https://eth-mainnet.alchemyapi.io/v2/" + process.env.ALCHEMY_TOKEN,
  blockNumber: process.env.LATESTBLOCK ? undefined : 14433300,
};

const forkingConfig =
  process.env.NETWORK === "polygon" ? polygonForkingConfig : mainnetForkingConfig;

const mochaConfig = {
  grep: "@forked-network",
  invert: process.env.FORK ? false : true,
  timeout: process.env.INTEGRATIONTEST ? INTEGRATIONTEST_TIMEOUT : 50000,
} as Mocha.MochaOptions;

const isPolygon = process.env.NETWORK === "polygon";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.6.10",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  namedAccounts: {
    deployer: 0,
  },
  networks: {
    hardhat: {
      forking: process.env.FORK ? forkingConfig : undefined,
      accounts: getHardhatPrivateKeys(),
      gas: isPolygon ? undefined : 12000000,
      blockGasLimit: isPolygon ? 20000000 : 12000000,
      // @ts-ignore
      timeout: INTEGRATIONTEST_TIMEOUT,
      initialBaseFeePerGas: 0,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      gas: isPolygon ? undefined : 12000000,
      blockGasLimit: isPolygon ? 20000000 : 12000000,
      // @ts-ignore
      timeout: INTEGRATIONTEST_TIMEOUT,
    },
    kovan: {
      url: "https://kovan.infura.io/v3/" + process.env.INFURA_TOKEN,
      // @ts-ignore
      accounts: [`0x${process.env.KOVAN_DEPLOY_PRIVATE_KEY}`],
    },
    production: {
      url: "https://mainnet.infura.io/v3/" + process.env.INFURA_TOKEN,
      // @ts-ignore
      accounts: [`0x${process.env.PRODUCTION_MAINNET_DEPLOY_PRIVATE_KEY}`],
    },
  },
  mocha: mochaConfig,
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
};

function getHardhatPrivateKeys() {
  return privateKeys.map(key => {
    const TEN_MILLION_ETH = "10000000000000000000000000";
    return {
      privateKey: key,
      balance: TEN_MILLION_ETH,
    };
  });
}

export default config;
