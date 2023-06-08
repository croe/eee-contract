import { expect } from "chai"
import { ethers } from "hardhat"
import { Coin, VWBLERC6105 } from "../typechain-types"
import { BigNumber } from "ethers"

const feeWei = ethers.utils.parseEther("0.001")
const baseURI = ""
const vwblNetworkUrl = "http://xxx.yyy.com"

describe("EEE scenario test", function () {
    it("scenario", async () => {
        // account
        const [owner, alice, bob] = await ethers.getSigners()

        // VWBL Gateway
        const VWBLGateway = await ethers.getContractFactory("VWBLGateway")
        const vwblGateway = await VWBLGateway.deploy(feeWei)
        // Gateway Proxy
        const GatewayProxy = await ethers.getContractFactory("GatewayProxy")
        const gatewayProxy = await GatewayProxy.deploy(vwblGateway.address)
        // VWBL NFT
        const AccessControlCheckerByNFT = await ethers.getContractFactory("AccessControlCheckerByNFT")
        const nftChecker = await AccessControlCheckerByNFT.deploy(gatewayProxy.address)

        // TODO ここから
        // deploy ft
        const Coin = await ethers.getContractFactory("Coin")
        const coin = (await Coin.deploy()) as Coin

        // deploy blueprint nft
        const VWBLERC6105 = await ethers.getContractFactory("VWBLERC6105")
        const blueprint = (await VWBLERC6105.deploy(
            baseURI,
            gatewayProxy.address,
            nftChecker.address,
            "Hello, VWBL"
        )) as VWBLERC6105

        // deploy parts nft
        const parts = (await VWBLERC6105.deploy(
            baseURI,
            gatewayProxy.address,
            nftChecker.address,
            "Hello, VWBL"
        )) as VWBLERC6105

        // TODO check args
        // deployer mints blueprints
        const royaltyPercentage = 0
        const documentId_3 = ethers.utils.randomBytes(32)
        await blueprint.mint(vwblNetworkUrl, royaltyPercentage, documentId_3, { value: feeWei })
        expect(await blueprint.ownerOf(1)).to.equal(owner.address)
        const documentId_4 = ethers.utils.randomBytes(32)
        await blueprint.mint(vwblNetworkUrl, royaltyPercentage, documentId_4, { value: feeWei })
        expect(await blueprint.ownerOf(2)).to.equal(owner.address)
        const documentId_5 = ethers.utils.randomBytes(32)
        await blueprint.mint(vwblNetworkUrl, royaltyPercentage, documentId_5, { value: feeWei })
        expect(await blueprint.ownerOf(3)).to.equal(owner.address)

        // TODO
        // only deployer can mint blueprints

        // deployer list blueprints to marketplace
        const blueprintSalePrice = BigNumber.from(10).pow(9).mul(ethers.utils.parseEther("5"))
        await blueprint["listItem(uint256,uint256,uint64,address)"](
            1,
            blueprintSalePrice,
            BigNumber.from(2).pow(64).sub(1), // max uint64
            coin.address
        )

        // mint tokens to arbitrary players
        await coin.mint(alice.address, BigNumber.from(10).pow(10).mul(ethers.utils.parseEther("1")))
        await coin.mint(bob.address, BigNumber.from(10).pow(10).mul(ethers.utils.parseEther("1")))

        // players buy blueprints with 5 billion tokens
        await coin.connect(alice).approve(blueprint.address, blueprintSalePrice)
        await blueprint.connect(alice).buyItem(1, blueprintSalePrice, coin.address)

        // now alice holds blueprint 1
        expect(await blueprint.ownerOf(1)).to.equal(alice.address)

        // players mint parts
        const documentId_6 = ethers.utils.randomBytes(32)
        await parts.connect(alice).mint(vwblNetworkUrl, royaltyPercentage, documentId_6, { value: feeWei })
        expect(await parts.ownerOf(1)).to.equal(alice.address)

        // players list parts on marketplace
        const partsSalePrice = BigNumber.from(10).pow(9).mul(ethers.utils.parseEther("1"))
        await parts.connect(alice)["listItem(uint256,uint256,uint64,address)"](
            1,
            partsSalePrice,
            BigNumber.from(2).pow(64).sub(1), // max uint64
            coin.address
        )

        // TODO
        // other players buy parts with deposit of twice of the price
        await coin.connect(bob).approve(parts.address, partsSalePrice)
        await parts.connect(bob).buyItem(1, partsSalePrice, coin.address)

        // no claim

        // claim

        // players can list blueprints
        await blueprint.connect(alice)["listItem(uint256,uint256,uint64,address)"](
            1,
            blueprintSalePrice,
            BigNumber.from(2).pow(64).sub(1), // max uint64
            coin.address
        )

        // deployer can mint blueprints additional times
        const documentId_7 = ethers.utils.randomBytes(32)
        await blueprint.mint(vwblNetworkUrl, royaltyPercentage, documentId_7, { value: feeWei })
    })
})
