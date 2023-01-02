//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLNFTMarketplace1.sol";
import "./YLNFTMarketplace2.sol";


contract Auction is ERC1155Holder, ReentrancyGuard, Ownable {
    YLNFTMarketplace1 marketplaceContract1;
    YLNFTMarketplace2 marketplaceContract2;


    using Counters for Counters.Counter;
    Counters.Counter private _auctionIds;

    IERC721 public ylnft721;
    IERC1155 public ylnft1155;
    IERC20 public ylt20;

    enum AuctionState {Active, Release}

    struct AuctionItem {
        uint256 auctionId;
        uint256 tokenId;
        uint256 auStart;
        uint256 auEnd;
        uint256 highestBid;
        address owner;
        address highestBidder;
        uint256 amount;
        uint256 limitPrice;
        bool isERC721;
        AuctionState state;
    }

    event AdminSetBid(address admin, uint256 period, uint256 tokenId, uint256 amount, uint256 limitPrice, uint256 timestamp);
    event UserSetBid(address user, uint256 period, uint256 tokenId, uint256 amount, uint256 limitPrice, uint256 timestamp);
    event UserBidoffer(address user, uint256 price, uint256 tokenId, uint256 amount, uint256 bidId, uint256 timestamp);
    event BidWinner(address user, uint256 auctionId, uint256 tokenId, uint256 amount, uint256 timestamp);
    event BidNull(uint256 auctionId, uint256 tokenId, uint256 amount, address owner, uint256 timestamp);
    event AuctionItemEditted(address user, uint256 tokenId, uint256 period, uint256 limitPrice, uint256 timestamp);
    event AdminWithdrawTokens(address user, uint256 amount, uint256 timestamp);

    mapping(uint256 => AuctionItem) private idToAuctionItem;

    constructor(IERC721 _ylnft721, IERC1155 _ylnft1155, address _marketplaceContract1, address _marketplaceContract2, address _ylt20) {
        ylnft721 = _ylnft721;
        ylnft1155 = _ylnft1155;
        marketplaceContract1 = YLNFTMarketplace(_marketplaceContract1);
        marketplaceContract2 = YLNFTMarketplace(_marketplaceContract2);
        ylt20 = IERC20(_ylt20);
    }

    //get auction
    function getAuctionId() public view returns(uint256) {
        return _auctionIds.current();
    }

    //get auction data
    function getAuction(uint256 _auctionId) public view returns(AuctionItem memory) {
        return idToAuctionItem[_auctionId];
    }

    function getMarketFee() public view returns (uint256) {
        return marketplaceContract.marketfee();
    }

    //f.
    function MinterListNFT(uint256 _tokenId, uint256 _price, uint256 _amount, uint256 _limitPrice, uint256 _period, bool _isERC721) public returns(uint256) {
        require(marketplaceContract.isMarketOwner() == true, "You aren't the owner of marketplace");
         
        if(_isERC721){
            require(ylnft721.ownerOf(_tokenId) == msg.sender, "You haven't this token");
            require(ylnft721.getApproved(_tokenId) == address(this), "NFT must be approved to market");
            
            ylnft721.transferFrom(msg.sender, address(this), _tokenId);
        }
        else{
            require(ylnft1155.balanceOf(msg.sender, _tokenId) >= _amount, "You haven't this token");
            require(ylnft1155.isApprovedForAll(msg.sender, address(this)) == true, "NFT must be approved to market");
            
            ylnft1155.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");
        }

        uint256 _auctionId = 0;
        for(uint i = 1; i <= _auctionIds.current(); i++) {
            if(idToAuctionItem[i].tokenId == _tokenId) {
                _auctionId = idToAuctionItem[i].auctionId;
                break;
            }
        }

        if(_auctionId == 0) {
            _auctionIds.increment();
            _auctionId = _auctionIds.current();
            idToAuctionItem[_auctionId] = AuctionItem (
                _auctionId,
                _tokenId,
                block.timestamp,
                block.timestamp + _period * 86400,
                _price,
                msg.sender,
                msg.sender,
                _amount,
                _limitPrice,
                _isERC721,
                AuctionState.Active
            );
        } else {
            idToAuctionItem[_auctionId] = AuctionItem (
                _auctionId,
                _tokenId,
                block.timestamp,
                block.timestamp + _period * 86400,
                _price,
                msg.sender,
                msg.sender,
                _amount,
                _limitPrice,
                _isERC721,
                AuctionState.Active
            );
        }

        emit AdminSetBid(msg.sender, _period, _tokenId, _amount, _limitPrice, block.timestamp);
        return _auctionId;
    }

    //g.
    function BuyerListNFT(uint256 _tokenId, uint256 _price, uint256 _amount, uint256 _limitPrice, uint256 _period, bool _isERC721) public returns(uint256) {
        if(_isERC721){
            require(ylnft721.ownerOf(_tokenId) == msg.sender, "You haven't this token");
            require(ylnft721.getApproved(_tokenId) == address(this), "NFT must be approved to market");

            ylnft721.transferFrom(msg.sender, address(this), _tokenId);
        }
        else{
            require(ylnft1155.balanceOf(msg.sender, _tokenId) >= _amount, "You haven't this token");
            require(ylnft1155.isApprovedForAll(msg.sender, address(this)) == true, "NFT must be approved to market");

            ylnft1155.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");
        }
        uint256 _auctionId = 0;
        for(uint i = 1; i <= _auctionIds.current(); i++) {
            if(idToAuctionItem[i].tokenId == _tokenId) {
                _auctionId = idToAuctionItem[i].auctionId;
                break;
            }
        }

        if(_auctionId == 0) {
            _auctionIds.increment();
            _auctionId = _auctionIds.current();
            idToAuctionItem[_auctionId] = AuctionItem (
                _auctionId,
                _tokenId,
                block.timestamp,
                block.timestamp + _period * 86400,
                _price,
                msg.sender,
                msg.sender,
                _amount,
                _limitPrice,
                _isERC721,
                AuctionState.Active
            );
        } else {
            idToAuctionItem[_auctionId] = AuctionItem (
                _auctionId,
                _tokenId,
                block.timestamp,
                block.timestamp + _period * 86400,
                _price,
                msg.sender,
                msg.sender,
                _amount,
                _limitPrice,
                _isERC721,
                AuctionState.Active
            );
        }

        emit UserSetBid(msg.sender, _period, _tokenId, _amount, _limitPrice, block.timestamp);
        return _auctionId;    
    }

    function userBidOffer(uint256 _auctionId, uint256 _price, uint256 _amount, bool _isERC721) public {
        require(idToAuctionItem[_auctionId].state == AuctionState.Active, "This auction item is not active");
        require(idToAuctionItem[_auctionId].auEnd > block.timestamp, "The bidding period has already passed.");
        require(idToAuctionItem[_auctionId].highestBid < _price, "The bid price must be higher than before.");
        if(_isERC721)
            require(ylnft721.ownerOf(idToAuctionItem[_auctionId].tokenId) == address(this), "This token don't exist in market.");
        else
            require(ylnft1155.balanceOf(address(this), idToAuctionItem[_auctionId].tokenId) >= _amount, "This token don't exist in market.");
        idToAuctionItem[_auctionId].highestBid = _price;
        idToAuctionItem[_auctionId].highestBidder = msg.sender;

        emit UserBidoffer(msg.sender, _price, idToAuctionItem[_auctionId].tokenId, _amount, _auctionId, block.timestamp);
    }

    function withdrawBid(uint256 _auctionId, uint256 _amount, bool _isERC721) public nonReentrant {
        require(idToAuctionItem[_auctionId].state == AuctionState.Active, "This auction item is not active");
        require((ylnft721.ownerOf(idToAuctionItem[_auctionId].tokenId) == address(this)) || ylnft1155.balanceOf(address(this), idToAuctionItem[_auctionId].tokenId) >= idToAuctionItem[_auctionId].amount, "This token don't exist in market.");
        require(idToAuctionItem[_auctionId].auEnd < block.timestamp, "The bidding period have to pass.");
        require(idToAuctionItem[_auctionId].highestBidder == msg.sender, "The highest bidder can withdraw this token.");

        if(idToAuctionItem[_auctionId].owner == msg.sender) {
            bool isTransferred = ylt20.transferFrom(msg.sender, address(this), marketplaceContract.marketfee());
            require(isTransferred, "Insufficient Fund.");
            if(_isERC721){
                ylnft721.transferFrom(address(this), msg.sender, idToAuctionItem[_auctionId].tokenId);
            }else{
                ylnft1155.safeTransferFrom(address(this), msg.sender, idToAuctionItem[_auctionId].tokenId, idToAuctionItem[_auctionId].amount, "");
            }
            idToAuctionItem[_auctionId].state = AuctionState.Release;
            idToAuctionItem[_auctionId].owner = msg.sender;
            emit BidNull(_auctionId, idToAuctionItem[_auctionId].tokenId, idToAuctionItem[_auctionId].amount, msg.sender, block.timestamp);
        } else {
            bool isTransferred = ylt20.transferFrom(msg.sender, address(this), idToAuctionItem[_auctionId].highestBid + marketplaceContract.marketfee());
            require(isTransferred, "Insufficient Fund.");
            if(_isERC721)
                ylnft721.transferFrom(address(this), msg.sender, idToAuctionItem[_auctionId].tokenId);
            else 
                ylnft1155.safeTransferFrom(address(this), msg.sender, idToAuctionItem[_auctionId].tokenId, idToAuctionItem[_auctionId].amount, "");
            (bool sent) = ylt20.transfer(idToAuctionItem[_auctionId].owner, idToAuctionItem[_auctionId].highestBid);
            require(sent, "Failed to send token to the seller");
            if(_isERC721){
                idToAuctionItem[_auctionId].state = AuctionState.Release;
                idToAuctionItem[_auctionId].owner = msg.sender;
            }
            else{
                if(idToAuctionItem[_auctionId].amount == _amount){
                    idToAuctionItem[_auctionId].state = AuctionState.Release;
                    idToAuctionItem[_auctionId].owner = msg.sender;
                }
                else
                    idToAuctionItem[_auctionId].amount -= _amount;
            }
            emit BidWinner(msg.sender, _auctionId, idToAuctionItem[_auctionId].tokenId, idToAuctionItem[_auctionId].amount, block.timestamp);
        }
    }

    function withdrawNFTInstant(uint256 _auctionId, uint256 _amount, bool _isERC721) public nonReentrant {
        require(idToAuctionItem[_auctionId].owner != msg.sender, "You can't withdraw your NFT");
        require((ylnft721.ownerOf(idToAuctionItem[_auctionId].tokenId) == address(this)) || ylnft1155.balanceOf(address(this), idToAuctionItem[_auctionId].tokenId) >= idToAuctionItem[_auctionId].amount, "This token don't exist in market.");
        bool isTransferred = ylt20.transferFrom(msg.sender, address(this), idToAuctionItem[_auctionId].highestBid + marketplaceContract.marketfee());
        require(isTransferred, "Insufficient Fund.");
        if(_isERC721)
            ylnft721.transferFrom(address(this), msg.sender, idToAuctionItem[_auctionId].tokenId);
        else 
            ylnft1155.safeTransferFrom(address(this), msg.sender, idToAuctionItem[_auctionId].tokenId, idToAuctionItem[_auctionId].amount, "");
        (bool sent) = ylt20.transfer(idToAuctionItem[_auctionId].owner, idToAuctionItem[_auctionId].highestBid);
        require(sent, "Failed to send token to the seller");
        if(_isERC721){
                idToAuctionItem[_auctionId].state = AuctionState.Release;
                idToAuctionItem[_auctionId].owner = msg.sender;
        }
        else{
            if(idToAuctionItem[_auctionId].amount == _amount){
                idToAuctionItem[_auctionId].state = AuctionState.Release;
                idToAuctionItem[_auctionId].owner = msg.sender;
            }
            else
                idToAuctionItem[_auctionId].amount -= _amount;
        }
        emit BidWinner(msg.sender, _auctionId, idToAuctionItem[_auctionId].tokenId, idToAuctionItem[_auctionId].amount, block.timestamp);
    }

    function fetchAuctionItems() public view returns(AuctionItem[] memory) {
        uint256 total = _auctionIds.current();
        
        uint256 itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if(idToAuctionItem[i].state == AuctionState.Active) {
                itemCount++;
            }
        }

        AuctionItem[] memory items = new AuctionItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if(idToAuctionItem[i].state == AuctionState.Active) {
                items[index] = idToAuctionItem[i];
                index++;
            }
        }

        return items;
    }

    function withdrawToken(uint256 _amount) public nonReentrant {
        require(marketplaceContract.isMarketOwner() == true, "You aren't the owner of marketplace");
        require(ylt20.balanceOf(address(this)) >= _amount, "insufficient fund");
        (bool sent) = ylt20.transfer(msg.sender, _amount);
        require(sent, "Failed to send token");
        emit AdminWithdrawTokens(msg.sender, _amount, block.timestamp);
    }

    function editAuctionItems(uint256 _auctionId, uint256 _period, uint256 _limitPrice) public {
        require(idToAuctionItem[_auctionId].state == AuctionState.Active, "This auction item is not active");
        require(idToAuctionItem[_auctionId].owner == msg.sender, "You can't edit this auction item");
        idToAuctionItem[_auctionId].limitPrice = _limitPrice;
        idToAuctionItem[_auctionId].auEnd = idToAuctionItem[_auctionId].auStart + _period * 86400;
        emit AuctionItemEditted(msg.sender, idToAuctionItem[_auctionId].tokenId, _period, _limitPrice, block.timestamp);
    }
}
