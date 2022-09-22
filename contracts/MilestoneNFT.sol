// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./CreatorMgmt.sol";

contract MilestoneNFT is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256 => string) private _tokenURIs;
    address private creatorMgmtAddress;

    constructor(address _creatorMgmtAddress) ERC1155("") {
        creatorMgmtAddress = _creatorMgmtAddress;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
        internal
        virtual
    {
        _tokenURIs[tokenId] = _tokenURI;
    }

    // mint as creator
    function mintCreatorNFT(string memory _tokenURI, uint256 _price)
        public
        returns (uint256)
    {
        // check if creator
        require(
            CreatorMgmt(creatorMgmtAddress).isCreator(msg.sender),
            "Not a creator, register first"
        );
        // check if reach maximum milestone
        require(
            CreatorMgmt(creatorMgmtAddress).isLessMilestones(msg.sender),
            "You reach limit of milestone"
        );
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId, 1, "");
        _setTokenURI(newItemId, _tokenURI);
        /// after mint, please update CreatorMgnt NFTMilestone (call addMilestone)
        CreatorMgmt(creatorMgmtAddress).addMilestone(
            address(this),
            newItemId,
            _price
        );
        return newItemId;
    }

    // mint as a donator
    // TODO need to check whether elligible trough Mgmt contract
    function mintDonatorNFT(address artist, uint256 milestoneId)
        public
        returns (uint256)
    {
        // check if he eligible to mint the milestoneNFT?
        require(
            CreatorMgmt(creatorMgmtAddress).isEligibleToMint(
                artist,
                milestoneId
            ),
            "You are not elligible"
        );
        // need to check and not mint if already mint one
        _mint(
            msg.sender,
            CreatorMgmt(creatorMgmtAddress).getTokenId(artist, milestoneId),
            1,
            ""
        );
        // set to not be able to mint again for this milestoneId
        CreatorMgmt(creatorMgmtAddress).afterMintMilestone(artist, milestoneId);
        return milestoneId;
    }
}
