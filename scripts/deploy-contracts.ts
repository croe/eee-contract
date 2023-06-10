// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat"
import * as dotenv from "dotenv"
import { Blueprint, Coin, Parts } from "../typechain-types"
dotenv.config()

async function main() {
    const baseURI = process.env.METADATA_URL!
    console.log("VWBL Metadata URL: ", baseURI)

    const gatewayProxyContractAddress = process.env.GATEWAY_PROXY_ADDRESS!
    const accessControlCheckerByNFTContractAddress = process.env.ACCESS_CONTROL_CHECKER_BY_NFT_ADDRESS!
    const messageToBeSigned = process.env.MESSAGE_TO_BE_SIGNED!
    console.log("Message to be signed: ", messageToBeSigned)

    const Coin = await ethers.getContractFactory("Coin")
    const Blueprint = await ethers.getContractFactory("Blueprint")
    const Parts = await ethers.getContractFactory("Parts")

    // deploy coin
    let coin = (await Coin.deploy()) as Coin
    console.log("Coin Contract deployed to:", coin.address)

    // deploy blueprint
    let blueprint = (await Blueprint.deploy(
        baseURI,
        gatewayProxyContractAddress,
        accessControlCheckerByNFTContractAddress,
        messageToBeSigned
    )) as Blueprint
    console.log("Blueprint Contract deployed to:", blueprint.address)

    // deploy parts
    let parts = (await Parts.deploy(
        baseURI,
        gatewayProxyContractAddress,
        accessControlCheckerByNFTContractAddress,
        messageToBeSigned
    )) as Parts
    console.log("Parts Contract deployed to:", parts.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
