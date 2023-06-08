// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC6105 {

    /// @notice Emitted when a token is listed for sale or delisted
    /// @dev The zero `salePrice` indicates that the token is not for sale
    ///      The zero `expires` indicates that the token is not for sale
    /// @param tokenId - identifier of the token being listed
    /// @param from - address of who is selling the token
    /// @param salePrice - the price the token is being sold for
    /// @param expires - UNIX timestamp, the buyer could buy the token before expires
    /// @param supportedToken - contract addresses of supported token or zero address
    ///                         The zero address indicates that the supported token is ETH
    ///                         Buyer needs to purchase item with supported token
    /// @param benchmarkPrice - Additional price parameter, may be used when calculating royalties
    event UpdateListing(
        uint256 indexed tokenId,
        address indexed from,
        uint256 salePrice,
        uint64 expires,
        address supportedToken,
        uint256 benchmarkPrice
    );

    /// @notice Emitted when a token is being purchased
    /// @param tokenId - identifier of the token being purchased
    /// @param from - address of who is selling the token
    /// @param to - address of who is buying the token
    /// @param salePrice - the price the token is being sold for
    /// @param supportedToken - contract addresses of supported token or zero address
    ///                         The zero address indicates that the supported token is ETH
    ///                         Buyer needs to purchase item with supported token
    /// @param royalties - The amount of royalties paid on this purchase
    event Purchased(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 salePrice,
        address supportedToken,
        uint256 royalties
    );

    /// @notice Create or update a listing for `tokenId`
    /// @dev `salePrice` MUST NOT be set to zero
    /// @param tokenId - identifier of the token being listed
    /// @param salePrice - the price the token is being sold for
    /// @param expires - UNIX timestamp, the buyer could buy the token before expires
    /// @param supportedToken - contract addresses of supported token or zero address
    ///                         The zero address indicates that the supported token is ETH
    ///                         Buyer needs to purchase item with supported token
    /// Requirements:
    /// - `tokenId` must exist
    /// - Caller must be owner, authorised operators or approved address of the token
    /// - `salePrice` must not be zero
    /// - `expires` must be valid
    /// - Must emit an {UpdateListing} event.
    function listItem(
        uint256 tokenId,
        uint256 salePrice,
        uint64 expires,
        address supportedToken
    ) external;

    /// @notice Create or update a listing for `tokenId` with `benchmarkPrice`
    /// @dev `salePrice` MUST NOT be set to zero
    /// @param tokenId - identifier of the token being listed
    /// @param salePrice - the price the token is being sold for
    /// @param expires - UNIX timestamp, the buyer could buy the token before expires
    /// @param supportedToken - contract addresses of supported token or zero address
    ///                         The zero address indicates that the supported token is ETH
    ///                         Buyer needs to purchase item with supported token
    /// @param benchmarkPrice - Additional price parameter, may be used when calculating royalties
    /// Requirements:
    /// - `tokenId` must exist
    /// - Caller must be owner, authorised operators or approved address of the token
    /// - `salePrice` must not be zero
    /// - `expires` must be valid
    /// - Must emit an {UpdateListing} event.
    function listItem(
        uint256 tokenId,
        uint256 salePrice,
        uint64 expires,
        address supportedToken,
        uint256 benchmarkPrice
    ) external;

    /// @notice Remove the listing for `tokenId`
    /// @param tokenId - identifier of the token being delisted
    /// Requirements:
    /// - `tokenId` must exist and be listed for sale
    /// - Caller must be owner, authorised operators or approved address of the token
    /// - Must emit an {UpdateListing} event
    function delistItem(uint256 tokenId) external;

    /// @notice Buy a token and transfer it to the caller
    /// @dev `salePrice` and `supportedToken` must match the expected purchase price and token to prevent front-running attacks
    /// @param tokenId - identifier of the token being purchased
    /// @param salePrice - the price the token is being sold for
    /// @param supportedToken - contract addresses of supported token or zero address
    /// Requirements:
    /// - `tokenId` must exist and be listed for sale
    /// - `salePrice` must matches the expected purchase price to prevent front-running attacks
    /// - `supportedToken` must matches the expected purchase token to prevent front-running attacks
    /// - Caller must be able to pay the listed price for `tokenId`
    /// - Must emit a {Purchased} event
    function buyItem(uint256 tokenId, uint256 salePrice, address supportedToken) external payable;

    /// @notice Return the listing for `tokenId`
    /// @dev The zero sale price indicates that the token is not for sale
    ///      The zero expires indicates that the token is not for sale
    ///      The zero supported token address indicates that the supported token is ETH
    /// @param tokenId identifier of the token being queried
    /// @return the specified listing (sale price, expires, supported token, benchmark price)
    function getListing(uint256 tokenId) external view returns (uint256, uint64, address, uint256);
}