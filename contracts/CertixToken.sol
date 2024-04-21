// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract CertixToken is Initializable, ERC20BurnableUpgradeable, ERC20CappedUpgradeable, ERC20PausableUpgradeable,  OwnableUpgradeable {

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

    // Maps for blacklist and skipBurnFeesList
    mapping(address => bool) public blacklist;
    mapping(address => bool) public skipBurnFeesList;

    Tier[] public tiers;

    uint256 private constant RATE_DENOMINATOR = 10000; // Denominator to calculate burn rate

    function initialize(string memory _name, string memory _symbol, uint256 _maxSupply) public initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Capped_init(_maxSupply); // Initialize the cap
        __ERC20Pausable_init(); // Initialize the pausable functionality
        __ERC20Burnable_init();
        __Ownable_init(msg.sender);

        // Mint initial supply if specified and ensure it does not exceed max supply
        _mint(_msgSender(), _maxSupply);

        initializeTiers();
    }
    
    function initializeTiers() internal {
        // Initialize tiers with specified attributes
        tiers.push(Tier("NO_TIER", 0, false, false, false, false, 0, 0, 50, 9999, 9999, 9999)); // Maximum fees and no permissions
        tiers.push(Tier("Pioneer", 250e18, false, true, false, false, 1, 0, 50, 9999, 300, 9999));
        tiers.push(Tier("Prospector", 1000e18, true, true, false, false, 2, 0, 40, 300, 200, 9999));
        tiers.push(Tier("Artisan", 2500e18, true, true, true, true, 3, 32000, 30, 200, 100, 300));
        tiers.push(Tier("Baron", 10000e18, true, true, true, true, 5, 70000, 20, 100, 50, 200));
        tiers.push(Tier("Emperor", 20000e18, true, true, true, true, 10, type(uint256).max, 10, 0, 0, 100));
    }

    function getUserTierIndex(address _wallet) public view returns (uint256) {
        uint256 balance = balanceOf(_wallet);
        for (uint256 i = tiers.length; i > 0; i--) {
            if (balance >= tiers[i - 1].minCertixBalance) return i - 1;
        }
        return 0; // Returns 0 for NO_TIER
    }

    function getUserTier(address _wallet) public view returns (Tier memory) {
        return tiers[getUserTierIndex(_wallet)];
    }

    function getAllTiers() public view returns (Tier[] memory) {
        return tiers;
    }
    

    function addToBlacklist(address account) public onlyOwner {
        blacklist[account] = true;
    }

    function removeFromBlacklist(address account) public onlyOwner {
        blacklist[account] = false;
    }

    function addToSkipBurnFeesList(address account) public onlyOwner {
        skipBurnFeesList[account] = true;
    }

    function removeFromSkipBurnFeesList(address account) public onlyOwner {
        skipBurnFeesList[account] = false;
    }

    function transfer(address _to, uint256 _amount) public override returns (bool) {
        require(!blacklist[msg.sender] && !blacklist[_to], "ERC20: sender or recipient is blacklisted");

        uint256 burnAmount = 0;
        if (!skipBurnFeesList[msg.sender]) {
            burnAmount = calculateBurnAmount(msg.sender, _amount);
            super._burn(msg.sender, burnAmount);
        }

        uint256 amountWithoutBurn = _amount - burnAmount;
        return super.transfer(_to, amountWithoutBurn);
    }

    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        require(!blacklist[_from] && !blacklist[_to], "ERC20: sender or recipient is blacklisted");

        uint256 burnAmount = 0;
        if (!skipBurnFeesList[_from]) {
            burnAmount = calculateBurnAmount(_from, _amount);
            super._burn(_from, burnAmount);
        }

        uint256 amountWithoutBurn = _amount - burnAmount;
        return super.transferFrom(_from, _to, amountWithoutBurn);
    }

    function calculateBurnAmount(address sender, uint256 amount) public view returns (uint256) {
        if (skipBurnFeesList[sender]) {
            return 0;
        }
        return amount * getUserTier(sender).transactionBurnFee / RATE_DENOMINATOR;
    }

    // Function to pause the token transfers - can only be called by the owner
    function pause() public onlyOwner {
        _pause();
    }

    // Function to unpause the token transfers - can only be called by the owner
    function unpause() public onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, ERC20CappedUpgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    // Function to update a specific tier
    function updateTier(uint256 tierIndex, Tier memory params) public onlyOwner{
        require(tierIndex < tiers.length, "Tier index out of bounds");

        Tier storage tier = tiers[tierIndex];
        tier.name = params.name;
        tier.minCertixBalance = params.minCertixBalance;
        tier.canMint = params.canMint;
        tier.canMelt = params.canMelt;
        tier.canMerge = params.canMerge;
        tier.hasAuctionAccess = params.hasAuctionAccess;
        tier.magicItemLootingChance = params.magicItemLootingChance;
        tier.maxWeightForMergeInMilligrams = params.maxWeightForMergeInMilligrams;
        tier.transactionBurnFee = params.transactionBurnFee;
        tier.mintingFeePercentage = params.mintingFeePercentage;
        tier.meltingFeePercentage = params.meltingFeePercentage;
        tier.auctionFeePercentage = params.auctionFeePercentage;
    }
}