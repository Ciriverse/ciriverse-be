const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("CiriverseDAO Unit Tests", function () {
          let ciriverseDAO,
              ciriverseContract,
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
              ciriverseContract = await ethers.getContract("CiriverseDAO")
              ciriverseDAO = ciriverseContract.connect(deployer)
              milestoneNftContract = await ethers.getContract("MilestoneNFTv2")
              milestoneNft = milestoneNftContract.connect(deployer)
          })

          describe("createProposal functions", function () {
              it("add proposal as registered creator, with milestone NFTs setup. should success with s_proposals added", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(URI, PRICE)
                  await ciriverseDAO.createProposal(OPT_1, OPT_2)
                  let numProposal = await ciriverseDAO.getNumProposals(
                      deployer.address
                  )
                  const proposal = await ciriverseDAO.s_proposals(
                      deployer.address,
                      0
                  )
                  assert(numProposal.toString() == "1")
                  assert(proposal.option1.toString() == OPT_1)
                  assert(proposal.option2.toString() == OPT_2)
              })

              it("add proposal as registered creator, and Milestone NFTs setup, three times with different options expected success, s_proposals added and match accordingly", async function () {
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(URI, PRICE)
                  const LENGTH = 3
                  for (let i = 0; i < LENGTH; i++) {
                      await ciriverseDAO.createProposal(`${i}-1`, `${i}-2`)
                  }
                  let numProposal = await ciriverseDAO.getNumProposals(
                      deployer.address
                  )

                  assert(numProposal.toString() == LENGTH.toString())
                  for (let i = 0; i < LENGTH; i++) {
                      const proposal = await ciriverseDAO.s_proposals(
                          deployer.address,
                          i
                      )
                      assert(proposal.option1.toString() == `${i}-1`)
                      assert(proposal.option2.toString() == `${i}-2`)
                  }
              })

              it("add proposal as not registered creator, expected revert", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await expect(
                      ciriverseDAO.createProposal(OPT_1, OPT_2)
                  ).to.be.revertedWith("You must register first")
              })

              it("add proposal as registered creator, but without Milestone NFTs setup, expected revert", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await expect(
                      ciriverseDAO.createProposal(OPT_1, OPT_2)
                  ).to.be.revertedWith(
                      "Creator have'nt setup Milestone NFTs yet."
                  )
              })
          })

          describe("voteProposal functions", function () {
              it("vote creator proposal as NFT holder and active proposal. proposal voted", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(URI, PRICE)
                  await ciriverseDAO.createProposal(OPT_1, OPT_2)
                  let numProposal = await ciriverseDAO.getNumProposals(
                      deployer.address
                  )
                  // connect as donators
                  ciriverseDAO = ciriverseContract.connect(user)
                  milestoneNft = milestoneNftContract.connect(user)
                  await milestoneNft.donate(deployer.address, {
                      value: PRICE,
                  })
                  // have to mint milestone to elligible vote
                  await milestoneNft.mintDonatorNFT(deployer.address, 0)

                  await ciriverseDAO.voteOnProposal(deployer.address, 0, 0)
                  const proposal = await ciriverseDAO.s_proposals(
                      deployer.address,
                      0
                  )
                  assert(numProposal.toString() == "1")
                  assert(proposal.votesOpt1.toString() == "1")
                  assert(proposal.votesOpt2.toString() == "0")
              })

              it("vote creator proposal as non NFT holder and active proposal. should revert", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(URI, PRICE)
                  await ciriverseDAO.createProposal(OPT_1, OPT_2)
                  // connect as donators
                  ciriverseDAO = ciriverseContract.connect(user)
                  milestoneNft = milestoneNftContract.connect(user)

                  await expect(
                      ciriverseDAO.voteOnProposal(deployer.address, 0, 0)
                  ).to.be.revertedWith("Not reach any milestone")
              })

              it("vote creator proposal as NFT holder and not active proposal. should revert", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(URI, PRICE)
                  await ciriverseDAO.createProposal(OPT_1, OPT_2)
                  await network.provider.send("evm_increaseTime", [1801])
                  await network.provider.send("evm_mine") // this one will have +30 minutes as its timestamp
                  // connect as donators
                  ciriverseDAO = ciriverseContract.connect(user)
                  milestoneNft = milestoneNftContract.connect(user)

                  await milestoneNft.donate(deployer.address, {
                      value: PRICE,
                  })
                  // have to mint milestone to elligible vote
                  await milestoneNft.mintDonatorNFT(deployer.address, 0)

                  await expect(
                      ciriverseDAO.voteOnProposal(deployer.address, 0, 0)
                  ).to.be.revertedWith("DEADLINE_EXCEEDED")
              })

              it("vote creator proposal as NFT holder and active proposal but already reach max votes. should revert", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(URI, PRICE)
                  await ciriverseDAO.createProposal(OPT_1, OPT_2)

                  // connect as donators
                  ciriverseDAO = ciriverseContract.connect(user)
                  milestoneNft = milestoneNftContract.connect(user)
                  await milestoneNft.donate(deployer.address, {
                      value: PRICE,
                  })
                  // have to mint milestone to elligible vote
                  await milestoneNft.mintDonatorNFT(deployer.address, 0)

                  await ciriverseDAO.voteOnProposal(deployer.address, 0, 0)

                  await expect(
                      ciriverseDAO.voteOnProposal(deployer.address, 0, 0)
                  ).to.be.revertedWith("Already vote or not elligible")
              })
          })

          describe("executeProposal functions", function () {
              it("execute creator proposal as NFT holder and inactive proposal. proposal executed", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(URI, PRICE)
                  await ciriverseDAO.createProposal(OPT_1, OPT_2)

                  // connect as donators
                  ciriverseDAO = ciriverseContract.connect(user)
                  milestoneNft = milestoneNftContract.connect(user)
                  await milestoneNft.donate(deployer.address, {
                      value: PRICE,
                  })
                  // have to mint milestone to elligible vote
                  await milestoneNft.mintDonatorNFT(deployer.address, 0)

                  await ciriverseDAO.voteOnProposal(deployer.address, 0, 0)
                  await network.provider.send("evm_increaseTime", [1801])
                  await network.provider.send("evm_mine") // this one will have +30 minutes as its timestamp
                  await ciriverseDAO.executeProposal(deployer.address, 0)
                  const proposal = await ciriverseDAO.s_proposals(
                      deployer.address,
                      0
                  )

                  assert(proposal.result.toString() == OPT_1)
                  assert(proposal.executed.toString() == "true")
              })

              it("execute creator proposal as non NFT holder and inactive proposal. proposal revert", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(URI, PRICE)
                  await ciriverseDAO.createProposal(OPT_1, OPT_2)

                  // connect as donators
                  ciriverseDAO = ciriverseContract.connect(user)
                  milestoneNft = milestoneNftContract.connect(user)

                  await network.provider.send("evm_increaseTime", [1801])
                  await network.provider.send("evm_mine") // this one will have +30 minutes as its timestamp

                  await expect(
                      ciriverseDAO.executeProposal(deployer.address, 0)
                  ).to.be.revertedWith("Not reach any milestone")
              })

              it("execute creator proposal as NFT holder and active proposal. should revert", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(URI, PRICE)
                  await ciriverseDAO.createProposal(OPT_1, OPT_2)

                  // connect as donators
                  ciriverseDAO = ciriverseContract.connect(user)
                  milestoneNft = milestoneNftContract.connect(user)
                  await milestoneNft.donate(deployer.address, {
                      value: PRICE,
                  })
                  // have to mint milestone to elligible vote
                  await milestoneNft.mintDonatorNFT(deployer.address, 0)

                  await ciriverseDAO.voteOnProposal(deployer.address, 0, 0)

                  await expect(
                      ciriverseDAO.executeProposal(deployer.address, 0)
                  ).to.be.revertedWith("DEADLINE_NOT_EXCEEDED")
              })

              it("execute creator proposal as NFT holder and inactive proposal but already executed. should revert", async function () {
                  const OPT_1 = "OPT_1"
                  const OPT_2 = "OPT_2"
                  await milestoneNft.creatorRegister(NAME, PIC)
                  await milestoneNft.mintCreatorNFT(URI, PRICE)
                  await ciriverseDAO.createProposal(OPT_1, OPT_2)

                  // connect as donators
                  ciriverseDAO = ciriverseContract.connect(user)
                  milestoneNft = milestoneNftContract.connect(user)
                  await milestoneNft.donate(deployer.address, {
                      value: PRICE,
                  })
                  // have to mint milestone to elligible vote
                  await milestoneNft.mintDonatorNFT(deployer.address, 0)

                  await ciriverseDAO.voteOnProposal(deployer.address, 0, 0)
                  await network.provider.send("evm_increaseTime", [1801])
                  await network.provider.send("evm_mine") // this one will have +30 minutes as its timestamp
                  await ciriverseDAO.executeProposal(deployer.address, 0)

                  await expect(
                      ciriverseDAO.executeProposal(deployer.address, 0)
                  ).to.be.revertedWith("PROPOSAL_ALREADY_EXECUTED")
              })
          })
      })
