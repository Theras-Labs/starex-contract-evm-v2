import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
// require('@nomiclabs/hardhat-ethers');
// require('@openzeppelin/hardhat-upgrades');
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          evmVersion: "paris",
        },
      },
    ],
  },
};

export default config;
