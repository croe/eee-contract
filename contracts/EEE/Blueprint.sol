// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./VWBLERC6105.sol";

contract Blueprint is VWBLERC6105 {

    constructor(
        string memory _baseURI,
        address _gatewayProxy,
        address _accessCheckerContract,
        string memory _signMessage
    ) VWBLERC6105(_baseURI, _gatewayProxy, _accessCheckerContract, _signMessage) {}

    function mint(
        string memory _getKeyURl,
        uint256 _royaltiesPercentage,
        bytes32 _documentId
    ) public payable override onlyOwner returns (uint256) {
        require(_royaltiesPercentage == 0, "Blueprint: royalty is disabled"); 
        
        return super.mint(_getKeyURl, _royaltiesPercentage, _documentId); 
    }

}