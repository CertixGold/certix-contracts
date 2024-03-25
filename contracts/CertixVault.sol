// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract CertixVault is Initializable, OwnableUpgradeable {
    // Interfaces for USDT and XAUT tokens
    IERC20 public usdt;
    IERC20 public xaut;


    function initialize(address _usdtAddress, address _xautAddress) public initializer {
        __Ownable_init(msg.sender);

        usdt = IERC20(_usdtAddress);
        xaut = IERC20(_xautAddress);
    }
}