//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// we will brin in the openzeppelin ERC721 NFT functionality

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// security against transactions for multiple request
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MilestoneNFTv2.sol";

contract CollectibleNFT is ERC721URIStorage, ReentrancyGuard {
    using Counters for Counters.Counter;
    //counter allow us to keep track of tokenIds
    Counters.Counter private _tokenIds;

    uint256 public constant MAX_COLLECTIBLE = 10;

    address private milestoneAddress;

    // add list of collectible
    struct Collectible {
        uint256 price;
        string URI;
        bool minted;
        bool exist;
    }

    mapping(address => Collectible[]) private s_collectiblesArray;

    event MintCollectible(address indexed donator, uint256 tokenId);

    // constructor set up milestoneAddress address
    constructor(address _milestoneAddress) ERC721("Collectible Ciri", "Ciris") {
        milestoneAddress = _milestoneAddress;
    }

    function isLessCollectible(address creator) public view returns (bool) {
        return s_collectiblesArray[creator].length < MAX_COLLECTIBLE;
    }

    function addCollectible(string calldata _URI, uint256 price)
        internal
    // isRegistered(msg.sender) // isOwner(nftAddress, tokenId, creator)
    {
        // add milestone NFTs, check first if the sender registered, is actually own the NFT
        // then check if not more than max milestones
        // Check if the sender is creator
        require(
            MilestoneNFTv2(milestoneAddress).isCreator(msg.sender),
            "You must register first"
        );
        require(
            s_collectiblesArray[msg.sender].length < MAX_COLLECTIBLE,
            "You reach limit of collectible"
        );
        s_collectiblesArray[msg.sender].push(
            Collectible(price, _URI, false, true)
        );
    }

    // mint sending creator address, tokenId and URI????? (from MilestoneNFT contract)
    function mintToken(address creator, uint256 index)
        public
        payable
        returns (uint256)
    {
        // check if it is not minted
        bool isCanMint = isCollectibleCanMintAt(creator, index);
        require(isCanMint, "NFT Minted already or Not Exist");
        // check the msg.value is greater/equal than price
        uint256 price = getCollectibleAt(creator, index).price;
        require(msg.value >= price, "Price not meet");
        string memory _URI = getCollectibleAt(creator, index).URI;
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        // set collectible minted to true
        afterMintCollectible(creator, index);

        _mint(msg.sender, newItemId);
        // set the token URI: id and url
        _setTokenURI(newItemId, _URI);
        // give the marketplace the approval to transact between users
        // setApprovalForAll(contractAddress, true);
        // mint the token and set it for sale - return the id to do so

        // send money to creator
        (bool success, ) = payable(creator).call{value: msg.value}("");
        require(success, "Transfer failed");

        emit MintCollectible(msg.sender, newItemId);
        return newItemId;
    }

    function getCollectibles(address creator)
        public
        view
        returns (Collectible[] memory)
    {
        return s_collectiblesArray[creator];
    }

    function getCollectibleAt(address creator, uint256 index)
        public
        view
        returns (Collectible memory)
    {
        return s_collectiblesArray[creator][index];
    }

    function isCollectibleCanMintAt(address creator, uint256 index)
        public
        view
        returns (bool)
    {
        return (!s_collectiblesArray[creator][index].minted &&
            s_collectiblesArray[creator][index].exist);
    }

    function afterMintCollectible(address creator, uint256 index) internal {
        s_collectiblesArray[creator][index].minted = true;
    }
}
