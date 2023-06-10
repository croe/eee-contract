// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat"
import * as dotenv from "dotenv"
import { Blueprint, Coin, Parts, PartsTrader } from "../typechain-types"
dotenv.config()

async function main() {
    const partsAddress = process.env.PARTS_ADDRESS!
    const coinAddress = process.env.COIN_ADDRESS!

    const Parts = await ethers.getContractFactory("Parts")
    const PartsTrader = await ethers.getContractFactory("PartsTrader")

    // deploy trader
    let trader = (await PartsTrader.deploy(partsAddress, coinAddress)) as PartsTrader
    console.log("PartsTrader Contract deployed to:", trader.address)

    // update trader state of parts
    let parts = (await Parts.attach(partsAddress)) as Parts
    await parts.updateTrader(trader.address)
    console.log("Trader state of Parts updated")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
