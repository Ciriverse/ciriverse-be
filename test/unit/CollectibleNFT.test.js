const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Collectible NFTs Unit Tests", function () {
          let collectibleNft,
              collectibleNftContract,
              milestoneNft,
              milestoneNftContract
          const PRICE = ethers.utils.parseEther("0.2")
          const URI = "DUMMY_URI"
          const NAME = "DUMMY_NAME"
          const PIC = "DUMMY_PIC"

          beforeEach(async () => {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              user = accounts[1]
              await deployments.fixture(["all"])
              collectibleNftContract = await ethers.getContract(
                  "CollectibleNFT"
              )
              collectibleNft = collectibleNftContract.connect(deployer)
              milestoneNftContract = await ethers.getContract("MilestoneNFTv2")
              milestoneNft = milestoneNftContract.connect(deployer)
          })

          describe("addCollectible functions", function () {
              it("add collectible as registered creator, with not reached milestone, should success", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await collectibleNft.addCollectible(URI, PRICE)
                  let collectible = await collectibleNft.getCollectibleAt(
                      deployer.address,
                      0
                  )
                  assert(collectible.URI.toString() == URI)
                  assert(collectible.price.toString() == PRICE)
              })

              it("add collectible as not registered creator, should revert", async function () {
                  await expect(
                      collectibleNft.addCollectible(URI, PRICE)
                  ).to.be.revertedWith("You must register first")
              })

              it("add collectible as registered creator, with reached milestone, should revert", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  for (let i = 0; i < 10; i++) {
                      await collectibleNft.addCollectible(URI, PRICE)
                  }
                  await expect(
                      collectibleNft.addCollectible(URI, PRICE)
                  ).to.be.revertedWith("You reach limit of collectible")
              })

              it("mint nft as donator with existed collectible and not yet minted, with enough value, should success", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await collectibleNft.addCollectible(URI, PRICE)
                  collectibleNft = collectibleNftContract.connect(user)
                  await collectibleNft.mintToken(deployer.address, 0, {
                      value: PRICE,
                  })
                  let collectible = await collectibleNft.getCollectibleAt(
                      deployer.address,
                      0
                  )
                  assert(collectible.URI.toString() == URI)
                  assert(collectible.tokenId.toString() == "1")
              })

              it("mint nft as donator with existed collectible and not yet minted, with not enough value, should revert", async function () {
                  const LOWER_PRICE = ethers.utils.parseEther("0.1")

                  await milestoneNft.creatorRegister(NAME, PIC)
                  await collectibleNft.addCollectible(URI, PRICE)
                  collectibleNft = collectibleNftContract.connect(user)
                  await expect(
                      collectibleNft.mintToken(deployer.address, 0, {
                          value: LOWER_PRICE,
                      })
                  ).to.be.revertedWith("Price not meet")
              })

              it("mint nft as donator with existed collectible and minted already, with enough value, should revert", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await collectibleNft.addCollectible(URI, PRICE)
                  collectibleNft = collectibleNftContract.connect(user)
                  await collectibleNft.mintToken(deployer.address, 0, {
                      value: PRICE,
                  })
                  await expect(
                      collectibleNft.mintToken(deployer.address, 0, {
                          value: PRICE,
                      })
                  ).to.be.revertedWith("NFT Minted already or Not Exist")
              })

              it("mint nft as donator with not existed collectible, should revert", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  collectibleNft = collectibleNftContract.connect(user)
                  await expect(
                      collectibleNft.mintToken(deployer.address, 0, {
                          value: PRICE,
                      })
                  ).to.be.revertedWith("NFT Minted already or Not Exist")
              })
          })
      })
