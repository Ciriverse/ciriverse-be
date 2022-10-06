// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// 1st import as follows
import "hardhat/console.sol";

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
    string public name;
    string public symbol;

    mapping(uint256 => string) public tokenURI;

    // All structs
    struct Creator {
        address addr;
        string name;
        string pic;
        uint256 funds;
    }

    struct Milestone {
        uint256 price;
        address nftAddress;
        uint256 tokenId;
    }
    // add minted status
    struct MilestonePerDonator {
        uint256 fund;
        bool[5] status;
        bool[5] minted;
    }

    event UserCreated(address indexed creator, string name, string pic);

    event Donate(
        address indexed creator,
        address indexed donator,
        uint256 value
    );

    constructor() payable ERC1155("") {
        name = "Ciriverse";
        symbol = "CIRI";
    }

    uint256 public constant MAX_MILESTONE = 5;

    mapping(address => Creator) private s_creators;
    mapping(address => Milestone[]) private s_milestoneArray;
    mapping(address => mapping(address => MilestonePerDonator)) s_donators;
    mapping(address => uint256) private s_donatorsCount;
    Creator[] private s_creatorsList;

    modifier notRegistered(address creatorAddress) {
        Creator memory creator = s_creators[creatorAddress];
        if (creator.addr != address(0)) {
            revert AlreadyListed(creatorAddress);
        }
        _;
    }

    modifier isRegistered(address creatorAddress) {
        Creator memory creator = s_creators[creatorAddress];
        if (creator.addr == address(0)) {
            revert NotListed(creatorAddress);
        }
        _;
    }

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

    // register as a creator
    // TODO
    // check if user already exist?
    function creatorRegister(string calldata _name, string calldata _pic)
        external
        notRegistered(msg.sender)
    {
        s_creators[msg.sender] = Creator(msg.sender, _name, _pic, 0);
        s_creatorsList.push(Creator(msg.sender, _name, _pic, 0));
        emit UserCreated(msg.sender, _name, _pic);
    }

    function updateProfile(string calldata _name, string calldata _pic)
        external
        isRegistered(msg.sender)
    {
        s_creators[msg.sender].name = _name;
        s_creators[msg.sender].pic = _pic;
        emit UserCreated(msg.sender, _name, _pic);
    }

    // gift creator a klay
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
                    console.log("jadi elligible?");
                    // check if donator already own?
                    // if not own and eligible, send the NFTs
                    // TODO comeback to this latter when we create NFT contract
                }
            }
        }
        emit Donate(creator, msg.sender, msg.value);
    }

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
        console.log("is it go here?");
        s_milestoneArray[msg.sender].push(
            Milestone(price, nftAddress, tokenId)
        );
        console.log("reach here?");
    }

    /*
     * @notice Method for withdrawing from donators
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

    function getFunds(address creator) external view returns (uint256) {
        return s_creators[creator].funds;
    }

    function isLessMilestones(address creator) public view returns (bool) {
        return s_milestoneArray[creator].length < MAX_MILESTONE;
    }

    function isCreator(address _address) public view returns (bool) {
        Creator memory creator = s_creators[_address];
        if (creator.addr == address(0)) {
            return false;
        }
        return true;
    }

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

    function getTokenId(address creator, uint256 milestoneId)
        public
        view
        returns (uint256)
    {
        return s_milestoneArray[creator][milestoneId].tokenId;
    }

    // pr disini update nya harus bener address nya
    function afterMintMilestone(address creator, uint256 milestoneId) internal {
        s_donators[msg.sender][creator].minted[milestoneId] = true;
    }

    function getCreator(address creator)
        external
        view
        returns (Creator memory)
    {
        return s_creators[address(creator)];
    }

    function getDonatorsCount(address creator) external view returns (uint256) {
        return s_donatorsCount[creator];
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
        internal
        virtual
    {
        tokenURI[tokenId] = _tokenURI;
    }

    // mint as creator
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

    // mint as a donator
    // TODO need to check whether elligible trough Mgmt contract
    function mintDonatorNFT(address artist, uint256 milestoneId)
        public
        payable
        returns (uint256)
    {
        // check if he eligible to mint the milestoneNFT?
        require(
            isEligibleToMint(artist, msg.sender, milestoneId),
            "You are not elligible"
        );
        // need to check and not mint if already mint one
        _mint(msg.sender, getTokenId(artist, milestoneId), 1, "");
        // set to not be able to mint again for this milestoneId
        afterMintMilestone(artist, milestoneId);
        return milestoneId;
    }

    function uri(uint256 _id) public view override returns (string memory) {
        return tokenURI[_id];
    }

    function getCreators() public view returns (Creator[] memory) {
        return s_creatorsList;
    }

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
}
