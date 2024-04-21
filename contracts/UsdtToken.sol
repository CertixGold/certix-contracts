// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import des contrats ERC20 et Ownable d'OpenZeppelin
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Déclaration du contrat qui hérite de ERC20 et Ownable
contract UsdtToken is ERC20 {
    // Constructeur pour initialiser le token avec un nom et un symbole
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        // Fonction _mint pour créer des tokens initiaux, assignés à l'adresse du propriétaire (deployer)
        _mint(msg.sender, initialSupply);
    }
}