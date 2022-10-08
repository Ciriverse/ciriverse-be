// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error AmountToLow(address sender, address creator, uint256 donate);
error ItemNotForSale(address nftAddress, uint256 tokenId);
error NotListed(address creatorAddress);
error AlreadyListed(address creatorAddress);
error NoFunds();
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();

contract MilestoneNFTv2 is ReentrancyGuard, ERC1155 {
    using Counters for Counters.Counter;
    // ERC1155 data
    Counters.Counter private _tokenIds;

    // ERC1155 name
    string public name;
    // ERC1155 symbol
    string public symbol;
    // mapping to store tokenURI
    mapping(uint256 => string) public tokenURI;
    /// All structs ///

    // creator struct
    struct Creator {
        address addr;
        string name;
        string pic;
        uint256 funds;
    }

    // milestone struct
    struct Milestone {
        uint256 price;
        address nftAddress;
        uint256 tokenId;
    }

    // MilestonePerDonator struct, to track fund, status of eligible to mint, and minted status
    struct MilestonePerDonator {
        uint256 fund;
        bool[5] status;
        bool[5] minted;
    }

    /// Events ///

    // event after user created
    event UserCreated(address indexed creator, string name, string pic);

    // event after donate happened
    event Donate(
        address indexed creator,
        address indexed donator,
        uint256 value
    );

    // Maximum milestone NFT
    uint256 public constant MAX_MILESTONE = 5;
    // mapping for creators address to its profile
    mapping(address => Creator) private s_creators;
    // mapping for creators to its milestone array
    mapping(address => Milestone[]) private s_milestoneArray;
    // mapping for donators to mapping of its supported creators and MilestonePerDonators
    mapping(address => mapping(address => MilestonePerDonator)) s_donators;
    // mapping for each creators to its donators count
    mapping(address => uint256) private s_donatorsCount;
    // list of creators
    Creator[] private s_creatorsList;

    // constructor to set ERC1155 name and symbol
    constructor() payable ERC1155("") {
        name = "Ciriverse";
        symbol = "CIRI";
    }

    ///  modifiers ///

    // check if not yet registered as a creator
    modifier notRegistered(address creatorAddress) {
        Creator memory creator = s_creators[creatorAddress];
        if (creator.addr != address(0)) {
            revert AlreadyListed(creatorAddress);
        }
        _;
    }

    // check if yet registered as a creator
    modifier isRegistered(address creatorAddress) {
        Creator memory creator = s_creators[creatorAddress];
        if (creator.addr == address(0)) {
            revert NotListed(creatorAddress);
        }
        _;
    }

    // check if the creator is owner of the IERC1155 token
    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address creator
    ) {
        IERC1155 nft = IERC1155(nftAddress);
        uint256 count = nft.balanceOf(creator, tokenId);
        if (count == 0) {
            revert NotOwner();
        }
        _;
    }

    /// external functions ///

    /**
     * @dev register new user, require _name and _pic input
     * require address is not registered
     */
    function creatorRegister(string calldata _name, string calldata _pic)
        external
        notRegistered(msg.sender)
    {
        s_creators[msg.sender] = Creator(msg.sender, _name, _pic, 0);
        s_creatorsList.push(Creator(msg.sender, _name, _pic, 0));
        emit UserCreated(msg.sender, _name, _pic);
    }

    /**
     * @dev update profile, require new _name and _pic
     * require address is registered as creator
     */
    function updateProfile(string calldata _name, string calldata _pic)
        external
        isRegistered(msg.sender)
    {
        s_creators[msg.sender].name = _name;
        s_creators[msg.sender].pic = _pic;
        emit UserCreated(msg.sender, _name, _pic);
    }

    /**
     * @dev send donate to creator
     * require creator address is registed as creator
     * require msg.value >= 0.1 ether
     */
    function donate(address creator)
        external
        payable
        isRegistered(creator)
        nonReentrant
    {
        if (msg.value < 0.1 ether) {
            revert AmountToLow(msg.sender, creator, msg.value);
        }
        s_creators[creator].funds += msg.value;
        if (s_donators[msg.sender][creator].fund == 0) {
            s_donatorsCount[creator] += 1;
        }
        s_donators[msg.sender][creator].fund += msg.value;
        uint256 milestoneCount = s_milestoneArray[creator].length;

        if (milestoneCount > 0) {
            for (uint256 i = 0; i < milestoneCount; i++) {
                // check if donator reach the milestone?
                // check if already marked true?
                if (
                    (s_donators[msg.sender][creator].fund >=
                        s_milestoneArray[creator][i].price) &&
                    s_donators[msg.sender][creator].minted[i] == false
                ) {
                    s_donators[msg.sender][creator].status[i] = true;
                    // check if donator already own?
                    // if not own and eligible, send the NFTs
                    // TODO comeback to this latter when we create NFT contract
                }
            }
        }
        emit Donate(creator, msg.sender, msg.value);
    }

    /**
     * @dev Method for withdrawing as creators from donators
     */
    function withdrawFunds() external {
        uint256 funds = s_creators[msg.sender].funds;
        if (funds <= 0) {
            revert NoFunds();
        }
        s_creators[msg.sender].funds = 0;
        (bool success, ) = payable(msg.sender).call{value: funds}("");
        require(success, "Transfer failed");
    }

    /**
     * @dev Method for get creator funds
     */
    function getFunds(address creator) external view returns (uint256) {
        return s_creators[creator].funds;
    }

    /**
     * @dev Method for get creator profile
     */
    function getCreator(address creator)
        external
        view
        returns (Creator memory)
    {
        return s_creators[address(creator)];
    }

    /**
     * @dev Method for get creator donators count
     */
    function getDonatorsCount(address creator) external view returns (uint256) {
        return s_donatorsCount[creator];
    }

    /// public functions ///

    /**
     * @dev Method for mint NFT as creator require input '_tokenURI' and 'price'
     * require the caller is creator and is not reach maximum minting milestone
     */
    function mintCreatorNFT(string memory _tokenURI, uint256 _price)
        public
        payable
        returns (uint256)
    {
        // check if creator
        require(isCreator(msg.sender), "Not a creator, register first");
        // check if reach maximum milestone
        require(isLessMilestones(msg.sender), "You reach limit of milestone");
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId, 1, "");
        _setTokenURI(newItemId, _tokenURI);
        // after mint, please update CreatorMgnt NFTMilestone (call addMilestone)
        addMilestone(address(this), newItemId, _price);
        return newItemId;
    }

    /**
     * @dev Method for mint NFT as donator require input 'creator' and 'milestoneId'
     * require the caller is eligible to mint
     */
    function mintDonatorNFT(address creator, uint256 milestoneId)
        public
        payable
        returns (uint256)
    {
        // check if he eligible to mint the milestoneNFT?
        require(
            isEligibleToMint(creator, msg.sender, milestoneId),
            "You are not elligible"
        );
        // need to check and not mint if already mint one
        _mint(msg.sender, getTokenId(creator, milestoneId), 1, "");
        // set to not be able to mint again for this milestoneId
        afterMintMilestone(creator, milestoneId);
        return milestoneId;
    }

    /**
     * @dev Method to check if creator not reach maximum milestone
     */
    function isLessMilestones(address creator) public view returns (bool) {
        return s_milestoneArray[creator].length < MAX_MILESTONE;
    }

    /**
     * @dev Method to check the address is registered as creator
     */
    function isCreator(address _address) public view returns (bool) {
        Creator memory creator = s_creators[_address];
        if (creator.addr == address(0)) {
            return false;
        }
        return true;
    }

    /**
     * @dev Method to check the creator is eligible to mint creator ERC1155 for spesific milestoneId
     */
    function isEligibleToMint(
        address creatorAddress,
        address donator,
        uint256 milestoneId
    ) public view returns (bool) {
        if (
            s_donators[donator][creatorAddress].status[milestoneId] == true &&
            s_donators[donator][creatorAddress].minted[milestoneId] == false
        ) {
            return true;
        }
        return false;
    }

    /**
     * @dev Method to return votes count, related to minted MilestoneNFTs
     */
    function getVotesCount(address creatorAddress, address donator)
        public
        view
        returns (uint256)
    {
        uint256 voteCount = 0;
        for (uint256 i = 0; i < 5; i++) {
            if (s_donators[donator][creatorAddress].minted[i] == true) {
                voteCount++;
            }
        }
        return voteCount;
    }

    /**
     * @dev Method to get tokenId from the spesific creator milestoneId
     */
    function getTokenId(address creator, uint256 milestoneId)
        public
        view
        returns (uint256)
    {
        return s_milestoneArray[creator][milestoneId].tokenId;
    }

    /**
     * @dev Method to get ERC1155 uri from tokenId
     */
    function uri(uint256 _id) public view override returns (string memory) {
        return tokenURI[_id];
    }

    /**
     * @dev Method to get all creator list
     */
    function getCreators() public view returns (Creator[] memory) {
        return s_creatorsList;
    }

    /**
     * @dev Method to get milestones for spesific creator
     */
    function getMilestones(address creator)
        public
        view
        returns (string[] memory)
    {
        uint256 milestoneCount = s_milestoneArray[creator].length;

        string[] memory uris = new string[](milestoneCount);

        if (milestoneCount > 0) {
            for (uint256 i = 0; i < milestoneCount; i++) {
                uris[i] = uri(s_milestoneArray[creator][i].tokenId);
            }
        }

        return uris;
    }

    /// internal functions ///

    /**
     * @dev Method to add milestone, require 'nftAddress', 'tokenId' and the 'price'
     * require the caller is registered as creator
     */
    function addMilestone(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        internal
        isRegistered(msg.sender) // isOwner(nftAddress, tokenId, creator)
    {
        // add milestone NFTs, check first if the sender registered, is actually own the NFT
        // then check if not more than max milestones
        require(
            s_milestoneArray[msg.sender].length < MAX_MILESTONE,
            "You reach limit of milestone"
        );
        s_milestoneArray[msg.sender].push(
            Milestone(price, nftAddress, tokenId)
        );
    }

    /**
     * @dev Method to update donator mint status after they mint milestone NFT
     */
    function afterMintMilestone(address creator, uint256 milestoneId) internal {
        s_donators[msg.sender][creator].minted[milestoneId] = true;
    }

    /**
     * @dev Method to set ERC1155 token URI
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
        internal
        virtual
    {
        tokenURI[tokenId] = _tokenURI;
    }
}
