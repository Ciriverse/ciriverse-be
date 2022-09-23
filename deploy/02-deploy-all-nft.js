const { network } = require("hardhat")
const {
    developmentChains,
    VERIFICATION_BLOCK_CONFIRMATIONS,
} = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const waitBlockConfirmations = developmentChains.includes(network.name)
        ? 1
        : VERIFICATION_BLOCK_CONFIRMATIONS
    const creatorMgmt = await ethers.getContract("CreatorMgmt")
    log("----------------------------------------------------")
    const args = [creatorMgmt.address]
    const milestoneNft = await deploy("MilestoneNFT", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: waitBlockConfirmations,
    })

    const basicNftTwo = await deploy("CollectibleNFT", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: waitBlockConfirmations,
    })

    // Verify the deployment
    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY
    ) {
        log("Verifying...")
        await verify(basicNft.address, args)
        await verify(basicNftTwo.address, args)
    }
    log("----------------------------------------------------")
}

module.exports.tags = ["all", "nfts"]