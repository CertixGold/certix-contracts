// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

// Declaring the contract which is initializable for upgradeability, and inheriting ERC721 functionality, ownership, and URI storage.
contract CertixNFT is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable, OwnableUpgradeable {

    // Structure to hold item type information, including its supply limit, current supply, and weight in gold.
    struct ItemType {
        uint256 supplyLimit;
        uint256 currentSupply;
        uint256 burnCount;
        uint256 goldWeightInGrams;
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

    // Contract initialization function, replacing the constructor for upgradeable contracts.
    function initialize(string memory _name, string memory _symbol) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721URIStorage_init();
        __Ownable_init(msg.sender);
    }

    // Function to mint new tokens, ensuring the supply limit for the item type has not been reached.
    function mint(address _to, string memory _itemType, string memory _uri) public onlyOwner {
        ItemType storage item = itemTypes[_itemType];
        require(item.currentSupply < item.supplyLimit, "Supply limit reached for this item type");
        uint256 tokenId = tokenIdCounter;

        item.currentSupply += 1;
        tokenIdCounter += 1;
        tokenIdToItemType[tokenId] = _itemType;
        tokensByType[_itemType].push(tokenId);
        
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _uri);
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

    // Overrides required by Solidity for the ERC721 and URI storage functionalities.
    function burn(uint256 _tokenId) public onlyOwner {
        _burn(_tokenId);
        itemTypes[tokenIdToItemType[_tokenId]].burnCount += 1;
    }
    
    // Functions to define or update item types and their properties. These functions are protected by the `onlyOwner` modifier.
    function defineItemType(string memory _itemType, uint256 _supplyLimit, uint256 _goldWeightInGrams) public onlyOwner {
        // Check if item type exists
        if (itemTypes[_itemType].supplyLimit == 0) {
            // Add new type if it doesn't exist
            itemTypesList.push(_itemType);
        }

        itemTypes[_itemType] = ItemType(_supplyLimit, 0, 0, _goldWeightInGrams);
    }

    // Function to set the supply limit for a specific item type. 
    function setItemSupplyLimit(string memory _itemType, uint256 _supplyLimit) public onlyOwner {
        require(itemTypes[_itemType].supplyLimit != 0, "ItemType does not exist");
        itemTypes[_itemType].supplyLimit = _supplyLimit;
    }

    // Function to set the gold weight in grams for a specific item type. 
    function setItemGoldWeight(string memory _itemType, uint256 _goldWeightInGrams) public onlyOwner {
        require(itemTypes[_itemType].supplyLimit != 0, "ItemType does not exist");
        itemTypes[_itemType].goldWeightInGrams = _goldWeightInGrams;
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
}