//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// we will brin in the openzeppelin ERC721 NFT functionality

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// security against transactions for multiple request
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MilestoneNFTv2.sol";

contract CollectibleNFT is ERC721URIStorage, ReentrancyGuard {
    using Counters for Counters.Counter;
    // ERC721 data
    //counter allow us to keep track of tokenIds
    Counters.Counter private _tokenIds;

    /// structs ///

    // add list of collectible
    struct Collectible {
        uint256 price;
        string URI;
        uint256 tokenId;
        bool minted;
        bool exist;
    }

    /// events ///
    event MintCollectible(address indexed donator, uint256 tokenId);

    uint256 public constant MAX_COLLECTIBLE = 10;
    address private milestoneAddress;
    mapping(address => Collectible[]) private s_collectiblesArray;

    // constructor set up milestoneAddress address
    constructor(address _milestoneAddress) ERC721("Collectible Ciri", "Ciris") {
        milestoneAddress = _milestoneAddress;
    }

    /// external functions ///

    /**
     * @dev add collectible as creators
     */
    function addCollectible(string calldata _URI, uint256 price) external {
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
            Collectible(price, _URI, 0, false, true)
        );
    }

    /// public functions ///

    /**
     * @dev mint token, require the collectible can be minted
     */
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
        // set collectible tokenId after mint
        setCollectibleTokenId(creator, index, newItemId);
        // set the token URI: id and url
        _setTokenURI(newItemId, _URI);

        // send money to creator
        (bool success, ) = payable(creator).call{value: msg.value}("");
        require(success, "Transfer failed");

        emit MintCollectible(msg.sender, newItemId);
        return newItemId;
    }

    /**
     * @dev check if collectible not reach max count
     */
    function isLessCollectible(address creator) public view returns (bool) {
        return s_collectiblesArray[creator].length < MAX_COLLECTIBLE;
    }

    /**
     * @dev get collectibles for spesific creator
     */
    function getCollectibles(address creator)
        public
        view
        returns (Collectible[] memory)
    {
        return s_collectiblesArray[creator];
    }

    /**
     * @dev get collectibles for spesific creator at spesific index
     */
    function getCollectibleAt(address creator, uint256 index)
        public
        view
        returns (Collectible memory)
    {
        return s_collectiblesArray[creator][index];
    }

    /**
     * @dev check if collectible can be minted
     */
    function isCollectibleCanMintAt(address creator, uint256 index)
        public
        view
        returns (bool)
    {
        if (s_collectiblesArray[creator].length == 0) {
            return false;
        }
        if (index + 1 > s_collectiblesArray[creator].length) {
            return false;
        }
        return (!s_collectiblesArray[creator][index].minted &&
            s_collectiblesArray[creator][index].exist);
    }

    /// internal functions ///

    /**
     * @dev set the minted status to true
     */
    function afterMintCollectible(address creator, uint256 index) internal {
        s_collectiblesArray[creator][index].minted = true;
    }

    /**
     * @dev set collectible tokenId after mint
     */
    function setCollectibleTokenId(
        address creator,
        uint256 index,
        uint256 newTokenId
    ) internal {
        s_collectiblesArray[creator][index].tokenId = newTokenId;
    }
}
