//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// we will brin in the openzeppelin ERC721 NFT functionality

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// security against transactions for multiple request
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CollectibleNFT is ERC721URIStorage, ReentrancyGuard {
    using Counters for Counters.Counter;
    //counter allow us to keep track of tokenIds
    Counters.Counter private _tokenIds;

    address private creatorMgmtAddress;

    event MintCollectible(address indexed donator, uint256 tokenId);

    // constructor set up CreatorMgmt address
    constructor(address _creatorMgmtAddress)
        ERC721("Collectible Ciri", "Ciris")
    {
        creatorMgmtAddress = _creatorMgmtAddress;
    }

    // mint sending creator address and URI????? (from CreatorMgmt contract)
    function mintToken(string memory tokenURI) public returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        // set the token URI: id and url
        _setTokenURI(newItemId, tokenURI);
        // give the marketplace the approval to transact between users
        // setApprovalForAll(contractAddress, true);
        // mint the token and set it for sale - return the id to do so

        emit MintCollectible(msg.sender, newItemId);
        return newItemId;
    }
}
