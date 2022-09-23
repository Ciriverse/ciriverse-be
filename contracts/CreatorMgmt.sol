// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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

contract CreatorMgmt is ReentrancyGuard {
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

    struct MilestonePerDonator {
        uint256 fund;
        bool[5] status;
    }

    event UserCreated(address indexed creator, string name, string pic);

    event Donate(
        address indexed creator,
        address indexed donator,
        uint256 value
    );

    uint256 public constant MAX_MILESTONE = 5;

    mapping(address => Creator) private s_creators;
    mapping(address => Milestone[]) private s_milestoneArray;
    mapping(address => mapping(address => MilestonePerDonator)) s_donators;

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
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (creator != owner) {
            revert NotOwner();
        }
        _;
    }

    // register as a creator
    // TODO
    // check if user already exist?
    function creatorRegister(string calldata name, string calldata pic)
        external
        notRegistered(msg.sender)
    {
        s_creators[msg.sender] = Creator(msg.sender, name, pic, 0);
        emit UserCreated(msg.sender, name, pic);
    }

    function updateProfile(string calldata name, string calldata pic)
        external
        isRegistered(msg.sender)
    {
        s_creators[msg.sender].name = name;
        s_creators[msg.sender].pic = pic;
        emit UserCreated(msg.sender, name, pic);
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
        s_donators[msg.sender][creator].fund += msg.value;
        uint256 milestoneCount = s_milestoneArray[creator].length;

        if (milestoneCount > 0) {
            for (uint256 i = 0; i < milestoneCount; i++) {
                // check if donator reach the milestone?
                // check if already marked true?
                if (
                    (s_donators[msg.sender][creator].fund >=
                        s_milestoneArray[creator][i].price)
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
        address creator,
        uint256 tokenId,
        uint256 price
    ) external isRegistered(creator) // isOwner(nftAddress, tokenId, creator)
    {
        // add milestone NFTs, check first if the sender registered, is actually own the NFT
        // then check if not more than max milestones
        require(
            s_milestoneArray[creator].length < MAX_MILESTONE,
            "You reach limit of milestone"
        );
        console.log("is it go here?");
        s_milestoneArray[creator].push(Milestone(price, nftAddress, tokenId));
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

    function isLessMilestones(address creator) external view returns (bool) {
        return s_milestoneArray[creator].length < MAX_MILESTONE;
    }

    function isCreator(address creatorAddress) external view returns (bool) {
        Creator memory creator = s_creators[creatorAddress];
        if (creator.addr == address(0)) {
            return false;
        }
        return true;
    }

    function isEligibleToMint(
        address creatorAddress,
        address donator,
        uint256 milestoneId
    ) external view returns (bool) {
        if (s_donators[donator][creatorAddress].status[milestoneId] == true) {
            return true;
        }
        return false;
    }

    function getTokenId(address creator, uint256 milestoneId)
        external
        view
        returns (uint256)
    {
        return s_milestoneArray[creator][milestoneId].tokenId;
    }

    function afterMintMilestone(address creator, uint256 milestoneId) external {
        s_donators[msg.sender][creator].status[milestoneId] = false;
    }

    function getCreator(address creator)
        external
        view
        returns (Creator memory)
    {
        return s_creators[address(creator)];
    }
}
