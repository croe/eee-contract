// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./VWBLERC6105.sol";

contract PartsTrader {

    event UpdateTrade(
        address indexed buyer,
        uint256 indexed tokenId,
        TradeStatus indexed status,
        uint256 deposit
    );

    enum TradeStatus {
        NoTrade, 
        DepositAndBuyParts,
        CompleteTrade,
        Claimed
    }

    struct Trade {
        address buyer;
        uint256 deposit;
        TradeStatus status;
    }

    VWBLERC6105 public parts;
    IERC20 public coin;
    mapping(uint256 => Trade) public tradesMap;

    constructor(address _parts, address _coin) {
        parts = VWBLERC6105(_parts);
        coin = IERC20(_coin);

        coin.approve(address(parts), type(uint256).max);
    }

    modifier onlyBuyer(uint256 tokenId) {
        Trade memory trade = tradesMap[tokenId];
        address buyer = trade.buyer;
        require(msg.sender == buyer, "PartsTrader: only buyer");
        _;
    }

    function depositAndBuyParts(uint256 tokenId) external {
        Trade storage trade = tradesMap[tokenId];
        require(trade.buyer == address(0), "PartsTrader: another buyer deposit for token");

        uint256 salePrice;
        uint256 historicalPrice;

        (salePrice, , , historicalPrice) = parts.getListing(tokenId);

        trade.buyer = msg.sender;
        trade.deposit = salePrice;
        trade.status = TradeStatus.DepositAndBuyParts; 

        coin.transferFrom(msg.sender, address(this), salePrice * 2);
        parts.buyItem(tokenId, salePrice, address(coin));
        parts.safeTransferFrom(address(this), msg.sender, tokenId);

        emit UpdateTrade(msg.sender, tokenId, TradeStatus.DepositAndBuyParts, salePrice);
    }

    function completeTrade(uint256 tokenId) external onlyBuyer(tokenId) {
        Trade storage trade = tradesMap[tokenId];
        coin.transfer(msg.sender, trade.deposit);

        emit UpdateTrade(msg.sender, tokenId, TradeStatus.CompleteTrade, trade.deposit);
        delete tradesMap[tokenId];
    }

    function claim(uint256 tokenId) external onlyBuyer(tokenId) {
        Trade storage trade = tradesMap[tokenId];
        coin.transfer(msg.sender, trade.deposit);

        emit UpdateTrade(msg.sender, tokenId, TradeStatus.Claimed, trade.deposit);
        delete tradesMap[tokenId];
    }

}