// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./VWBLERC6105.sol";

contract Parts is VWBLERC6105 {

    address public trader; 

    constructor(
        string memory _baseURI,
        address _gatewayProxy,
        address _accessCheckerContract,
        string memory _signMessage
    ) VWBLERC6105(_baseURI, _gatewayProxy, _accessCheckerContract, _signMessage) {}

    modifier onlyTrader() { 
        require(msg.sender == trader, "Parts: only trader"); 
        _; 
    }

    function mint(
        string memory _getKeyURl,
        uint256 _royaltiesPercentage,
        bytes32 _documentId
    ) public payable override returns (uint256) {
        require(_royaltiesPercentage == 0, "Blueprint: royalty is disabled"); 
        return super.mint(_getKeyURl, _royaltiesPercentage, _documentId); 
    }

    function buyItem(
        uint256 tokenId, 
        uint256 salePrice, 
        address supportedToken
    ) public payable override onlyTrader {
        super.buyItem(tokenId, salePrice, supportedToken);
    }

    function updateTrader(address _trader) external onlyOwner { 
        trader = _trader; 
    }
}