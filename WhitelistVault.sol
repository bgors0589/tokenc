// SPDX-License-Identifier: Unlicense
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable@3.4.1/access/OwnableUpgradeable.sol";

contract WhitelistVault is OwnableUpgradeable {

    bool public freewayMode = false;

    mapping(address => bool) private _allowed;

    event AddedToWhiteList(address _address);
    event RemoveFromWhiteList(address _address);

    function initialize() public {
        __Ownable_init();
    }

    function addToWhitelist(address[] memory whitelisted) public onlyOwner {
      for (uint c = 0; c < whitelisted.length; c++ )
        _addToWhitelist(whitelisted[c]);
    }

    function _addToWhitelist(address whitelisted) private {
        require(whitelisted != address(0), "WhitelistVault: whitelisted is the zero address");
        _allowed[whitelisted] = true;
        emit AddedToWhiteList(whitelisted);
    }

    function removeFromWhitelist(address[] memory blacklisted) public onlyOwner {
      for (uint c = 0; c < blacklisted.length; c++ )
        _removeFromWhitelist(blacklisted[c]);
    }

    function _removeFromWhitelist(address blacklisted) private {
        require(blacklisted != address(0), "WhitelistVault: blacklisted is the zero address");
        if (_allowed[blacklisted]){
          _allowed[blacklisted] = false;
          emit RemoveFromWhiteList(blacklisted);
        }
    }

    function setFreewayMode(bool mode) public onlyOwner {
      freewayMode = mode;
    }

    function isWhitelisted(address _address) public view returns (bool) {
      if (freewayMode) {
        return true;
      }
      return _allowed[_address] == true;
    }
}
