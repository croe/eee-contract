// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IERC6105.sol";
import "../access-condition/ERC721/VWBL.sol";

/// @title No Intermediary NFT Trading Protocol with Value-added Royalty
/// @dev The royalty scheme used by this reference implementation is Value-Added Royalty
contract VWBLERC6105 is VWBL, IERC6105, ReentrancyGuard {

    /// @dev A structure representing a listed token
    ///      The zero `salePrice` indicates that the token is not for sale 
    ///      The zero `expires` indicates that the token is not for sale
    /// @param salePrice - the price the token is being sold for
    /// @param expires - UNIX timestamp, the buyer could buy the token before expires
    /// @param supportedToken - contract addresses of supported ERC20 token or zero address
    ///                         The zero address indicates that the supported token is ETH
    ///                         Buyer needs to purchase item with supported token
    /// @param historicalPrice - The price at which the seller last bought this token
    struct Listing {
        uint256 salePrice;
        uint64 expires;
        address supportedToken;
        uint256 historicalPrice;
    }

    // Mapping from token Id to listing index
    mapping(uint256 => Listing) private _listings;

    constructor(
        string memory _baseURI,
        address _gatewayProxy,
        address _accessCheckerContract,
        string memory _signMessage
    ) VWBL(_baseURI, _gatewayProxy, _accessCheckerContract, _signMessage) {}

    /// @notice Create or update a listing for `tokenId`
    /// @dev `salePrice` MUST NOT be set to zero
    /// @param tokenId - identifier of the token being listed
    /// @param salePrice - the price the token is being sold for
    /// @param expires - UNIX timestamp, the buyer could buy the token before expires
    /// @param supportedToken - contract addresses of supported ERC20 token or zero address
    ///                         The zero address indicates that the supported token is ETH
    ///                         Buyer needs to purchase item with supported token
    function listItem(
        uint256 tokenId,
        uint256 salePrice,
        uint64 expires,
        address supportedToken
    ) external virtual {
        listItem(tokenId, salePrice, expires, supportedToken, 0);
    }

    /// @notice Create or update a listing for `tokenId` with `historicalPrice`
    /// @dev `price` MUST NOT be set to zero
    /// @param tokenId - identifier of the token being listed
    /// @param salePrice - the price the token is being sold for
    /// @param expires - UNIX timestamp, the buyer could buy the token before expires
    /// @param supportedToken - contract addresses of supported ERC20 token or zero address
    ///                         The zero address indicates that the supported token is ETH
    ///                         Buyer needs to purchase item with supported token
    /// @param historicalPrice - The price at which the seller last bought this token
    function listItem(
        uint256 tokenId,
        uint256 salePrice,
        uint64 expires,
        address supportedToken,
        uint256 historicalPrice
    ) public virtual {

        address tokenOwner = ownerOf(tokenId);
        require(salePrice > 0, "ERC6105: token sale price MUST NOT be set to zero");
        require(expires > block.timestamp, "ERC6105: invalid expires");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC6105: caller is not owner nor approved");

        _listings[tokenId] = Listing(salePrice, expires, supportedToken, historicalPrice);
        emit UpdateListing(tokenId, tokenOwner, salePrice, expires, supportedToken, historicalPrice);
    }

    /// @notice Remove the listing for `tokenId`
    /// @param tokenId - identifier of the token being listed
    function delistItem(uint256 tokenId) external virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC6105: caller is not owner nor approved");
        require(_isForSale(tokenId), "ERC6105: invalid listing");

        _removeListing(tokenId);
    }

    /// @notice Buy a token and transfers it to the caller
    /// @dev `salePrice` and `supportedToken` must match the expected purchase price and token to prevent front-running attacks
    /// @param tokenId - identifier of the token being purchased
    /// @param salePrice - the price the token is being sold for
    /// @param supportedToken - contract addresses of supported token or zero address
    function buyItem(uint256 tokenId, uint256 salePrice, address supportedToken) external nonReentrant payable virtual {
        address tokenOwner = ownerOf(tokenId);
        address buyer = msg.sender;
        uint256 historicalPrice = _listings[tokenId].historicalPrice;

        require(salePrice == _listings[tokenId].salePrice, "ERC6105: inconsistent prices");
        require(supportedToken == _listings[tokenId].supportedToken, "ERC6105: inconsistent tokens");
        require(_isForSale(tokenId), "ERC6105: invalid listing");

        /// @dev Handle royalties
        (address royaltyRecipient, uint256 royalties) = _calculateRoyalties(tokenId, salePrice, historicalPrice);

        uint256 payment = salePrice - royalties;
        if (supportedToken == address(0)) {
            require(msg.value == salePrice, "ERC6105: incorrect value");
            if (royalties > 0) { 
                _processSupportedTokenPayment(royalties, buyer, royaltyRecipient, address(0));
            }
            _processSupportedTokenPayment(payment, buyer, tokenOwner, address(0));
        }
        else {
            uint256 num = IERC20(supportedToken).allowance(buyer, address(this));
            require(num >= salePrice, "ERC6105: insufficient allowance");
            if (royalties > 0) { 
                _processSupportedTokenPayment(royalties, buyer, royaltyRecipient, supportedToken);
            }
            _processSupportedTokenPayment(payment, buyer, tokenOwner, supportedToken);
        }

        _transfer(tokenOwner, buyer, tokenId);
        emit Purchased(tokenId, tokenOwner, buyer, salePrice, supportedToken, royalties);
    }

    /// @notice Return the listing for `tokenId`
    /// @dev The zero sale price indicates that the token is not for sale
    ///      The zero expires indicates that the token is not for sale
    ///      The zero supported token address indicates that the supported token is ETH
    /// @param tokenId identifier of the token being queried
    /// @return the specified listing (sale price, expires, supported token, benchmark price)
    function getListing(uint256 tokenId) external view virtual returns (uint256, uint64, address, uint256) {
        if (_listings[tokenId].salePrice > 0 && _listings[tokenId].expires >= block.timestamp) {
            uint256 salePrice = _listings[tokenId].salePrice;
            uint64 expires = _listings[tokenId].expires;
            address supportedToken = _listings[tokenId].supportedToken;
            uint256 historicalPrice = _listings[tokenId].historicalPrice;
            return (salePrice, expires, supportedToken, historicalPrice);
        }
        else {
            return (0, 0, address(0), 0);
        }
    }

    /// @dev Remove the listing for `tokenId`
    /// @param tokenId - identifier of the token being delisted
    function _removeListing(uint256 tokenId) internal virtual {
        address tokenOwner = ownerOf(tokenId);
        delete _listings[tokenId];
        emit UpdateListing(tokenId, tokenOwner, 0, 0, address(0), 0);
    }

    /// @dev Check if the token is for sale
    function _isForSale(uint256 tokenId) internal virtual returns (bool){
        if (_listings[tokenId].salePrice > 0 && _listings[tokenId].expires >= block.timestamp) {
            return true;
        }
        else {
            return false;
        }
    }

    /// @dev Handle Value Added Royalty
    function _calculateRoyalties(
        uint256 tokenId,
        uint256 price,
        uint256 historicalPrice
    ) internal virtual returns (address, uint256){
        uint256 taxablePrice;
        if (price > historicalPrice) {
            taxablePrice = price - historicalPrice;
        }
        else {
            taxablePrice = 0;
        }

        (address royaltyRecipient, uint256 royalties) = royaltyInfo(tokenId, taxablePrice);
        return (royaltyRecipient, royalties);
    }

    /// @dev Process a `supportedToken` of `amount` payment to `recipient`.
    /// @param amount - the amount to send
    /// @param from - the payment payer
    /// @param recipient - the payment recipient
    /// @param supportedToken - contract addresses of supported ERC20 token or zero address
    ///                         The zero address indicates that the supported token is ETH
    function _processSupportedTokenPayment(
        uint256 amount,
        address from,
        address recipient,
        address supportedToken
    ) internal virtual {
        if (supportedToken == address(0))
        {
            (bool success,) = payable(recipient).call{value : amount}("");
            require(success, "Ether Transfer Fail");
        }
        else {
            (bool success) = IERC20(supportedToken).transferFrom(from, recipient, amount);
            require(success, "Supported Token Transfer Fail");
        }
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override  returns (bool) {
        return interfaceId == type(IERC6105).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Before transferring the NFT, need to delete listing
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        if (_isForSale(tokenId)) {
            _removeListing(tokenId);
        }
    }
}