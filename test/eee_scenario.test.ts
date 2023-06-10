import { expect } from "chai"
import { ethers } from "hardhat"
import { Blueprint, Coin, Parts, PartsTrader, VWBLERC6105 } from "../typechain-types"
import { BigNumber } from "ethers"

const feeWei = ethers.utils.parseEther("0.001")
const baseURI = ""
const vwblNetworkUrl = "http://xxx.yyy.com"

describe("EEE scenario test", function () {
    it("scenario", async () => {
        // account
        const [owner, alice, bob, carol] = await ethers.getSigners()

        // VWBL Gateway
        const VWBLGateway = await ethers.getContractFactory("VWBLGateway")
        const vwblGateway = await VWBLGateway.deploy(feeWei)
        // Gateway Proxy
        const GatewayProxy = await ethers.getContractFactory("GatewayProxy")
        const gatewayProxy = await GatewayProxy.deploy(vwblGateway.address)
        // VWBL NFT
        const AccessControlCheckerByNFT = await ethers.getContractFactory("AccessControlCheckerByNFT")
        const nftChecker = await AccessControlCheckerByNFT.deploy(gatewayProxy.address)

        // deploy ft
        const Coin = await ethers.getContractFactory("Coin")
        const coin = (await Coin.deploy()) as Coin

        // deploy blueprint nft
        const VWBLERC6105 = await ethers.getContractFactory("VWBLERC6105")
        const Blueprint = await ethers.getContractFactory("Blueprint")
        const blueprint = (await Blueprint.deploy(
            baseURI,
            gatewayProxy.address,
            nftChecker.address,
            "Hello, VWBL"
        )) as Blueprint

        // deploy parts nft
        const Parts = await ethers.getContractFactory("Parts")
        const parts = (await Parts.deploy(baseURI, gatewayProxy.address, nftChecker.address, "Hello, VWBL")) as Parts

        // deploy parts trader
        const PartsTrader = await ethers.getContractFactory("PartsTrader")
        const trader = (await PartsTrader.deploy(parts.address, coin.address)) as PartsTrader
        await parts.updateTrader(trader.address)

        // TODO
        // nfts supports all interfaces

        // TODO check args
        // deployer mints blueprints
        const documentId_3 = ethers.utils.randomBytes(32)
        await blueprint.mint(vwblNetworkUrl, 0, documentId_3, { value: feeWei })
        expect(await blueprint.ownerOf(1)).to.equal(owner.address)
        const documentId_4 = ethers.utils.randomBytes(32)
        await blueprint.mint(vwblNetworkUrl, 0, documentId_4, { value: feeWei })
        expect(await blueprint.ownerOf(2)).to.equal(owner.address)
        const documentId_5 = ethers.utils.randomBytes(32)
        await blueprint.mint(vwblNetworkUrl, 0, documentId_5, { value: feeWei })
        expect(await blueprint.ownerOf(3)).to.equal(owner.address)

        // royalty is disabled for nfts
        const documentId_6 = ethers.utils.randomBytes(32)
        await expect(blueprint.mint(vwblNetworkUrl, 1, documentId_6, { value: feeWei })).to.be.revertedWith(
            "Blueprint: royalty is disabled"
        )
        expect(await blueprint.ownerOf(3)).to.equal(owner.address)

        // only deployer can mint blueprints
        const documentId_7 = ethers.utils.randomBytes(32)
        await expect(
            blueprint.connect(alice).mint(vwblNetworkUrl, 0, documentId_7, { value: feeWei })
        ).to.be.revertedWith("Ownable: caller is not the owner")

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
        await coin.mint(carol.address, BigNumber.from(10).pow(10).mul(ethers.utils.parseEther("1")))

        // players buy blueprints with 5 billion tokens
        await coin.connect(alice).approve(blueprint.address, blueprintSalePrice)
        await blueprint.connect(alice).buyItem(1, blueprintSalePrice, coin.address)

        // now alice holds blueprint 1
        expect(await blueprint.ownerOf(1)).to.equal(alice.address)

        // players mint parts
        const documentId_8 = ethers.utils.randomBytes(32)
        const documentId_9 = ethers.utils.randomBytes(32)
        await parts.connect(alice).mint(vwblNetworkUrl, 0, documentId_8, { value: feeWei })
        expect(await parts.ownerOf(1)).to.equal(alice.address)
        await parts.connect(bob).mint(vwblNetworkUrl, 0, documentId_9, { value: feeWei })
        expect(await parts.ownerOf(1)).to.equal(alice.address)

        // players list parts on marketplace
        const partsSalePrice1 = BigNumber.from(10).pow(9).mul(ethers.utils.parseEther("1"))
        const partsSalePrice2 = BigNumber.from(10).pow(9).mul(ethers.utils.parseEther("2"))
        await parts.connect(alice)["listItem(uint256,uint256,uint64,address)"](
            1,
            partsSalePrice1,
            BigNumber.from(2).pow(64).sub(1), // max uint64
            coin.address
        )
        await parts.connect(bob)["listItem(uint256,uint256,uint64,address)"](
            2,
            partsSalePrice2,
            BigNumber.from(2).pow(64).sub(1), // max uint64
            coin.address
        )

        // trade without claim
        await coin.connect(bob).approve(trader.address, partsSalePrice1.mul(2))
        await trader.connect(bob).depositAndBuyParts(1)
        expect(await parts.ownerOf(1)).to.equal(bob.address)
        expect(await coin.balanceOf(trader.address)).to.equal(partsSalePrice1)
        let bobsTrade = await trader.tradesMap(1)
        expect(bobsTrade.buyer).to.equal(bob.address)
        expect(bobsTrade.deposit).to.equal(partsSalePrice1)
        expect(bobsTrade.status).to.equal(1) // deposited and bought
        // complete trade without claim
        await trader.connect(bob).completeTrade(1)
        let completedTrade = await trader.tradesMap(1)
        expect(completedTrade.buyer).to.equal(ethers.constants.AddressZero)
        expect(completedTrade.deposit).to.equal(0)
        expect(completedTrade.status).to.equal(0)

        // trade with claim
        await coin.connect(carol).approve(trader.address, partsSalePrice2.mul(2))
        await trader.connect(carol).depositAndBuyParts(2)
        expect(await parts.ownerOf(2)).to.equal(carol.address)
        expect(await coin.balanceOf(trader.address)).to.equal(partsSalePrice2)
        const trade = await trader.tradesMap(2)
        expect(trade.buyer).to.equal(carol.address)
        expect(trade.deposit).to.equal(partsSalePrice2)
        expect(trade.status).to.equal(1) // deposited and bought
        // complete trade with claim
        await trader.connect(carol).completeTrade(2)
        let completedTrade2 = await trader.tradesMap(2)
        expect(completedTrade2.buyer).to.equal(ethers.constants.AddressZero)
        expect(completedTrade2.deposit).to.equal(0)
        expect(completedTrade2.status).to.equal(0)

        // players can list blueprints
        await blueprint.connect(alice)["listItem(uint256,uint256,uint64,address)"](
            1,
            blueprintSalePrice,
            BigNumber.from(2).pow(64).sub(1), // max uint64
            coin.address
        )

        // deployer can mint blueprints additional times
        const documentId_10 = ethers.utils.randomBytes(32)
        await blueprint.mint(vwblNetworkUrl, 0, documentId_10, { value: feeWei })
    })
})
