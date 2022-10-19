# Ciriverse Smart Contracts

**Ciriverse Protocol Diagram**

![ Ciriverse Protocol Diagram](https://i.ibb.co/crqQ862/Ciriverse-Protocol-Diagram.png)

Consist of 3 Contracts :

1. `MilestoneNFTv2.sol` for ERC1155 main contracts to hold users and NFTs features gating.
2. `CollectibleNFT.sol` for ERC721 Collectibles to mint from creators.
3. `CiriverseDAO.sol` for Polling based on ownership of ERC1155 contract above.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
npx hardhat deploy --network baobab
```
Testnet Contracts :

- [Profile Graph and Milestone NFTs Contract](https://baobab.scope.klaytn.com/account/0xd8d78614A02A543f0fc27c1e4F41DF087816F98e?tabId=txList)
- [Collectible NFTs Contract](https://baobab.scope.klaytn.com/account/0x01Ebab7B1D0Ae2064311E7054844CE5c8dB96d96?tabId=txList)
- [Voting Contract](https://baobab.scope.klaytn.com/account/0x6064BB01e024059f03a47c5bCe02d0a0b84D45E2?tabId=txList)

