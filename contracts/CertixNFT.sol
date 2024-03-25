// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface CERTIX_TOKEN {
    struct Tier {
        string name;
        uint256 minCertixBalance;
        bool canMint;
        bool canMelt;
        bool canMerge;
        bool hasAuctionAccess;
        uint256 magicItemLootingChance;
        uint256 maxWeightForMergeInMilligrams;
        uint256 transactionBurnFee;
        uint256 mintingFeePercentage;
        uint256 meltingFeePercentage;
        uint256 auctionFeePercentage;
    }
    function getUserTier(address _wallet) external returns (Tier memory);
}



// Declaring the contract which is initializable for upgradeability, and inheriting ERC721 functionality, ownership, and URI storage.
contract CertixNFT is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable, OwnableUpgradeable {

    // Structure to hold item type information, including its supply limit, current supply, and weight in gold.
    struct ItemType {
        uint256 supplyLimit;
        uint256 currentSupply;
        uint256 burnCount;
        uint256 goldWeightInMilligrams; // Using milligrams for precision
        string[] metadataUris;
    }

    // A counter to keep track of token IDs.
    uint256 public tokenIdCounter;
    // Mapping from token ID to its item type.
    mapping(uint256 => string) public tokenIdToItemType;
    // Mapping from item type name to its details.
    mapping(string => ItemType) public itemTypes;
    //Mapping of token ids by item type name
    mapping(string => uint256[]) public tokensByType;
    string[] public itemTypesList;
    address public usdtAddress;
    uint256 public usdtPerGramGold;
    // Total weight in milligrams of Certix gold items
    uint256 public totalGoldWeightInMilligrams;

    // Contract initialization function, replacing the constructor for upgradeable contracts.
    function initialize(string memory _name, string memory _symbol) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721URIStorage_init();
        __Ownable_init(msg.sender);
    }

    // Function to mint new tokens, ensuring the supply limit for the item type has not been reached.
    function mint(address _to, string memory _itemType) public {
        ItemType storage item = itemTypes[_itemType];//Get the item

        //TODO CALL TIER CONTRACT -> CanMint(msg.sender)

        //Check supply limit
        require(item.currentSupply < item.supplyLimit, "Supply limit reached for this item type");
        //Check if an uri exists
        require(item.metadataUris.length > item.currentSupply, "Not enough metadata URIs provided");

        // Calculate the required USDT amount based on gold weight in milligrams
        // Assuming usdtPerGramGold is per gram, convert milligrams to grams for calculation
        uint256 requiredUsdtAmount = (item.goldWeightInMilligrams * usdtPerGramGold) / 1000;

        //Add item's weight
        addGoldWeight(item.goldWeightInMilligrams);

        //TODO Fees FROM Tier contract to cold wallet

        // Transfer USDT from the user to the contract
        //TODO THINK ABOUT IT -> VAULT ?
        require(IERC20(usdtAddress).transferFrom(msg.sender, address(this), requiredUsdtAmount), "USDT transfer failed");

        //Get token id
        uint256 tokenId = tokenIdCounter;
        //Get token uri
        string memory tokenUri = item.metadataUris[item.currentSupply];

        item.currentSupply += 1;
        tokenIdCounter += 1;
        tokenIdToItemType[tokenId] = _itemType;
        tokensByType[_itemType].push(tokenId);

        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, tokenUri);
    }

    // Overrides required by Solidity for the ERC721 and URI storage functionalities.
    function melt(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "You must own the token to melt it");

        ItemType storage itemType = itemTypes[tokenIdToItemType[_tokenId]];
        uint256 goldWeightInMilligrams = itemType.goldWeightInMilligrams;
        
        // Convert item weight from milligrams to troy ounces for XAU₮
        // 1 troy ounce = 31.1035 grams = 31,103.5 milligrams
        // Using Solidity to avoid floating-point precision issues
        uint256 xautAmount = (goldWeightInMilligrams * 10**18) / 31103500; // Adding 10**18 for precision

        _burn(_tokenId);
        itemType.burnCount += 1;

        //Remove item's weight
        removeGoldWeight(goldWeightInMilligrams);

        // Ensure your contract has enough XAU₮ to perform the transfer
        //TODO from vault
        //require(IERC20(xautAddress).transfer(msg.sender, xautAmount), "Failed to transfer XAU₮");

        // Adjust the burn count
        itemTypes[tokenIdToItemType[_tokenId]].burnCount += 1;
    }

    // Function to add gold weight when a new Certix NFT is minted
    function addGoldWeight(uint256 weightInMilligrams) public onlyOwner {
        totalGoldWeightInMilligrams += weightInMilligrams;
    }

    // Function to remove gold weight when an Certix NFT is burned
    function removeGoldWeight(uint256 weightInMilligrams) public onlyOwner {
        require(weightInMilligrams <= totalGoldWeightInMilligrams, "Insufficient gold weight");
        totalGoldWeightInMilligrams -= weightInMilligrams;
    }

    // Functions to define or update item types and their properties. These functions are protected by the `onlyOwner` modifier.
    function defineItemType(string memory _itemType, uint256 _supplyLimit, uint256 _goldWeightInMilligrams) public onlyOwner {
        // Check if item type doesn't exist
        require(itemTypes[_itemType].supplyLimit == 0, "Item type already defined");

        itemTypesList.push(_itemType);

        itemTypes[_itemType] = ItemType(_supplyLimit, 0, 0, _goldWeightInMilligrams, itemTypes[_itemType].metadataUris);
    }

    function addMultipleMetadataUrisStartingAtIndex(string memory _itemType, string[] memory _uris, uint256 _startIndex) public onlyOwner {
        require(itemTypes[_itemType].supplyLimit != 0, "ItemType does not exist");
        
        // Ensure the start index is within the current bounds of the array
        require(_startIndex <= itemTypes[_itemType].metadataUris.length, "Start index out of bounds");

        for (uint256 i = 0; i < _uris.length; i++) {
            uint256 currentIndex = _startIndex + i;

            // Check if we need to append or replace within the array
            if (currentIndex >= itemTypes[_itemType].metadataUris.length) {
                // Append the new URI to the array
                itemTypes[_itemType].metadataUris.push(_uris[i]);
            } else {
                // Replace the URI at the specified index
                itemTypes[_itemType].metadataUris[currentIndex] = _uris[i];
            }
        }
    }

    // Function to set the supply limit for a specific item type. 
    function setItemSupplyLimit(string memory _itemType, uint256 _supplyLimit) public onlyOwner {
        require(itemTypes[_itemType].supplyLimit != 0, "ItemType does not exist");
        itemTypes[_itemType].supplyLimit = _supplyLimit;
    }

    // Function to set the gold weight in grams for a specific item type. 
    function setItemGoldWeight(string memory _itemType, uint256 _goldWeightInMilligrams) public onlyOwner {
        require(itemTypes[_itemType].supplyLimit != 0, "ItemType does not exist");
        itemTypes[_itemType].goldWeightInMilligrams = _goldWeightInMilligrams;
    }

    // Function to get an array of token IDs owned by a specific address. Potentially gas-intensive for large datasets.
    function tokensOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        if (ownerTokenCount == 0) {
            return new uint256[](0) ; // Return an empty array if the owner has no tokens
        } else {
            uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
            for (uint256 index = 0; index < ownerTokenCount; index++) {
                ownedTokenIds[index] = tokenOfOwnerByIndex(_owner, index);
            }

            return ownedTokenIds;
        }
    }

    // Function to retrieve details for a list of item types.
    function getItemsDetails(string[] memory _itemTypes) public view returns (ItemType[] memory) {
        ItemType[] memory itemsDetails = new ItemType[](_itemTypes.length);
        for (uint256 i = 0; i < _itemTypes.length; i++) {
            if (itemTypes[_itemTypes[i]].supplyLimit != 0) { // Ensure the item type exists
                itemsDetails[i] = itemTypes[_itemTypes[i]];
            }
        }
        return itemsDetails;
    }

    // Function to retrieve details for all item types.
    function getAllItemsDetails() public view returns (ItemType[] memory) {
        return getItemsDetails(itemTypesList);
    }

    // Function to retrieve details for all item types.
    function getAllTypes() public view returns (string[] memory) {
        return itemTypesList;
    }

    // Override of the tokenURI function from the ERC721URIStorage extension.
    function tokenURI(uint256 _tokenId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        return super.tokenURI(_tokenId);
    }

    // Override of the supportsInterface function from the ERC721URIStorage extension.
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Override the conflicting functions
    function _increaseBalance(address account, uint128 value) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, value);
    }

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function setUsdtAddress(address _usdtAddress) public onlyOwner {
        usdtAddress = _usdtAddress;
    }

    function setUsdtPerGramGold(uint256 _usdtPerGramGold) public onlyOwner {
        usdtPerGramGold = _usdtPerGramGold;
    }

    function withdrawUsdt(uint256 _amount, address _to) public onlyOwner {
        require(IERC20(usdtAddress).transfer(_to, _amount), "USDT transfer failed");
    }
}