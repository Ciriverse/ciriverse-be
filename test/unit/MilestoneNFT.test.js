const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Milestone NFTs Unit Tests", function () {
          let milestoneNft, milestoneNftContract
          const NAME = "DUMMY_NAME"
          const PIC = "DUMMY_PIC"

          beforeEach(async () => {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              user = accounts[1]
              await deployments.fixture(["all"])
              milestoneNftContract = await ethers.getContract("MilestoneNFTv2")
              milestoneNft = milestoneNftContract.connect(deployer)
          })

          describe("creatorRegister functions", function () {
              it("Register user with previously not register", async function () {
                  expect(await milestoneNft.creatorRegister(NAME, PIC)).to.emit(
                      "UserCreated"
                  )
              })
              it("Register user with previously register, should revert with error", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await expect(
                      milestoneNft.creatorRegister(NAME, PIC)
                  ).to.be.revertedWithCustomError(milestoneNft, "AlreadyListed")
              })
              it("Registered user profile with pic and name", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  const creator = await milestoneNft.getCreator(
                      deployer.address
                  )
                  assert(creator.name.toString() == NAME)
                  assert(creator.pic.toString() == PIC)
              })
          })

          describe("updateProfile functions", function () {
              const NEW_NAME = "NEW_NAME"
              const NEW_PIC = "NEW_PIC"
              it("Update profile with previously registered user", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  expect(
                      await milestoneNft.updateProfile(NEW_NAME, NEW_PIC)
                  ).to.emit("UserCreated")
              })
              it("Update profile with previously not registered user, should revert error", async function () {
                  await expect(
                      milestoneNft.updateProfile(NEW_NAME, NEW_PIC)
                  ).to.be.revertedWithCustomError(milestoneNft, "NotListed")
              })
              it("Updated user profile with new pic and new name", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.updateProfile(NEW_NAME, NEW_PIC)
                  const creator = await milestoneNft.getCreator(
                      deployer.address
                  )
                  assert(creator.name.toString() == NEW_NAME)
                  assert(creator.pic.toString() == NEW_PIC)
              })
          })

          describe("donate functions", function () {
              const DONATE_FUND = ethers.utils.parseEther("0.2")
              it("donate to registered user as donators emit event", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  milestoneNft = milestoneNftContract.connect(user)
                  expect(
                      await milestoneNft.donate(deployer.address, {
                          value: DONATE_FUND,
                      })
                  ).to.emit("Donate")
              })
              it("donate to registered user as donators update s_donatorscount", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  const donators_count_before =
                      await milestoneNft.getDonatorsCount(deployer.address)
                  milestoneNft = milestoneNftContract.connect(user)
                  await milestoneNft.donate(deployer.address, {
                      value: DONATE_FUND,
                  })
                  const donators_count_after =
                      await milestoneNft.getDonatorsCount(deployer.address)
                  assert(
                      donators_count_before.add(1).toString() ==
                          donators_count_after.toString()
                  )
              })
              it("donate to registered user as donators update  s_creators funds", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  const creator_funds_before = await milestoneNft.getFunds(
                      deployer.address
                  )
                  milestoneNft = milestoneNftContract.connect(user)
                  await milestoneNft.donate(deployer.address, {
                      value: DONATE_FUND,
                  })
                  const creator_dunds_after = await milestoneNft.getFunds(
                      deployer.address
                  )
                  assert(
                      creator_funds_before.add(DONATE_FUND).toString() ==
                          creator_dunds_after.toString()
                  )
              })
              it("donate to not registered user as donators should revert", async function () {
                  milestoneNft = milestoneNftContract.connect(user)
                  await expect(
                      milestoneNft.donate(deployer.address, {
                          value: DONATE_FUND,
                      })
                  ).to.be.revertedWithCustomError(milestoneNft, "NotListed")
              })
          })

          describe("withdrawFunds functions", function () {
              const DONATE_FUND = ethers.utils.parseEther("0.2")
              it("withdraw with creators funds > 0, should update creator balance", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  const before_balance = await deployer.getBalance()
                  milestoneNft = milestoneNftContract.connect(user)
                  await milestoneNft.donate(deployer.address, {
                      value: DONATE_FUND,
                  })
                  // connect to creator again
                  milestoneNft = milestoneNftContract.connect(deployer)
                  const deployerProceedsBefore = await milestoneNft.getFunds(
                      deployer.address
                  )
                  const txResponse = await milestoneNft.withdrawFunds()
                  const transactionReceipt = await txResponse.wait(1)
                  const { gasUsed, effectiveGasPrice } = transactionReceipt
                  const gasCost = gasUsed.mul(effectiveGasPrice)
                  const after_balance = await deployer.getBalance()

                  assert(
                      after_balance.add(gasCost).toString() ==
                          before_balance.add(deployerProceedsBefore).toString()
                  )
              })

              it("withdraw with creators funds = 0, should revert", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)

                  await expect(
                      milestoneNft.withdrawFunds()
                  ).to.be.revertedWithCustomError(milestoneNft, "NoFunds")
              })
          })

          describe("mintCreatorNFT functions", function () {
              const DUMMY_PRICE = ethers.utils.parseEther("0.2")
              const DUMMY_URI = "DUMMY_URI"
              it("mint as creator with milestone count =< 5, s_milestoneArray updated", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  const milestones_before = await milestoneNft.getMilestones(
                      deployer.address
                  )
                  await milestoneNft.mintCreatorNFT(DUMMY_URI, DUMMY_PRICE)
                  const milestones_after = await milestoneNft.getMilestones(
                      deployer.address
                  )

                  assert(
                      milestones_after.length == milestones_before.length + 1
                  )

                  assert(milestones_after == DUMMY_URI)
              })

              it("mint as not registered creator, should revert", async function () {
                  await expect(
                      milestoneNft.mintCreatorNFT(DUMMY_URI, DUMMY_PRICE)
                  ).to.be.revertedWith("Not a creator, register first")
              })

              it("mint as creator with milestone count > 5, should revert", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  for (let i = 0; i < 5; i++) {
                      await milestoneNft.mintCreatorNFT(DUMMY_URI, DUMMY_PRICE)
                  }
                  await expect(
                      milestoneNft.mintCreatorNFT(DUMMY_URI, DUMMY_PRICE)
                  ).to.be.revertedWith("You reach limit of milestone")
              })
          })

          describe("mintDonatorNFT functions", function () {
              const DUMMY_PRICE = ethers.utils.parseEther("0.2")
              const DUMMY_URI = "DUMMY_URI"
              const DONATE_FUND = ethers.utils.parseEther("0.2")
              beforeEach(async () => {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(DUMMY_URI, DUMMY_PRICE)
                  milestoneNft = milestoneNftContract.connect(user)
              })
              it("mint as eligible donator, should minted and update s_donators", async function () {
                  await milestoneNft.donate(deployer.address, {
                      value: DONATE_FUND,
                  })
                  await milestoneNft.mintDonatorNFT(deployer.address, 0)

                  const tokenId = await milestoneNft.getTokenId(
                      deployer.address,
                      0
                  )
                  const balance = await milestoneNft.balanceOf(
                      user.address,
                      tokenId
                  )

                  assert(balance.toString() == "1")
              })

              it("mint as eligible donator, but has minted, should revert", async function () {
                  await milestoneNft.donate(deployer.address, {
                      value: DONATE_FUND,
                  })
                  await milestoneNft.mintDonatorNFT(deployer.address, 0)

                  await expect(
                      milestoneNft.mintDonatorNFT(deployer.address, 0)
                  ).to.be.revertedWith("You are not elligible")
              })

              it("mint as not eligible donator, should revert", async function () {
                  await expect(
                      milestoneNft.mintDonatorNFT(deployer.address, 0)
                  ).to.be.revertedWith("You are not elligible")
              })
          })
      })
