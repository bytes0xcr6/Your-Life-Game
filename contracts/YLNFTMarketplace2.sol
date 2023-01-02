//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//import "hardhat/console.sol";

contract YLNFTMarketplace2 is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _auctionIds;

    IERC721 public ylnft;
    
    uint256 public marketcommission = 5;
    uint256 public marketfee = 0.5 ether;
    address public _marketplaceOwner;

    enum AuctionState {Active, Release}
    enum State { Active, Inactive, Release}

    struct AuctionItem {
        uint256 auctionId;
        uint256 tokenId;
        uint256 auStart;
        uint256 auEnd;
        uint256 highestBid;
        address owner;
        address highestBidder;
        AuctionState state;
    }
    struct MarketItem {
        uint256 itemId;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        State state;
    }

    event UserNFTDirectTransferto(address user, uint256 tokenId, address to, uint256 price, uint256 gas, uint256 commission, uint256 timestamp);
    event AdminWithdrawFromEscrow(address admin, uint256 amount, uint256 timestamp);
    event AdminPauselistedNFT(address user, uint256 tokenId, address marketplace, uint256 timestamp);
    event AdminUnpauselistedNFT(address user, uint256 tokenId, address marketplace, uint256 timestamp);
    event PurchasedNFT(address user, uint256 tokenId, uint256 amount, uint256 price, uint256 commission, uint256 gas);
    event SoldNFT(uint256 tokenId, uint256 amount, address market, uint256 timestamp);
    event UserNFTtoMarketSold(uint256 tokenId, address user, uint256 price, uint256 commission, uint256 timestamp);
    event MarketVCommisionSet(address admin, uint256 commission, uint256 timestamp);
    event AdminTransferNFT(address admin, uint256 tokenId, uint256 amount, address user, uint256 timestamp);
    event AdminSetBid(address admin, uint256 period, uint256 tokenId, uint256 amount, uint256 timestamp);
    event UserSetBid(address user, uint256 period, uint256 tokenId, uint256 amount, uint256 timestamp);
    event UserBidoffer(address user, uint256 price, uint256 tokenId, uint256 amount, uint256 bidId, uint256 timestamp);
    event BidWinner(address user, uint256 auctionId, uint256 tokenId, uint256 timestamp);
    event BidNull(uint256 auctionId, uint256 tokenId, uint256 amount, address owner, uint256 timestamp);

    mapping(address => bool) private marketplaceOwners;
    mapping(uint256 => AuctionItem) private idToAuctionItem;
    
    modifier ylOwners() {
        require(marketplaceOwners[msg.sender] == true, "You aren't the owner of marketplace");
        _;
    }

    constructor(IERC721 _ylnft) {
        ylnft = _ylnft;
        marketplaceOwners[msg.sender] = true;
        _marketplaceOwner = msg.sender;
    }

    //get owner
    function getOwner(address _owner) public view returns(bool) {
        return marketplaceOwners[_owner];
    }

    //c. Marketplace Credential
    function allowCredential(address _mOwner, bool _flag) public ylOwners returns(bool) {
        marketplaceOwners[_mOwner] = _flag;
        return true;
    }

    //get auction
    function getAuctionId() public view returns(uint256) {
        return _auctionIds.current();
    }
    
    //get auction data
    function getAuction(uint256 _auctionId) public view returns(AuctionItem memory) {
        return idToAuctionItem[_auctionId];
    }
    
    // Get Market Fee
    function getMarketFee() external view returns(uint256) {
        return marketfee;
    }

    // Setting Market Fee
    function setMarketFee(uint256 _fee) public ylOwners {
        marketfee = _fee;
        emit MarketVCommisionSet(msg.sender, marketfee, block.timestamp);
    }

    // Setting Market commission
    function setMarketcommission(uint256 _commission) public ylOwners {
        marketcommission = _commission;
        emit MarketVCommisionSet(msg.sender, marketcommission, block.timestamp);
    }
    
    //f.
    function bidMinterNFT(uint256 _tokenId, uint256 _price, uint256 _period) public ylOwners returns(uint256) {
        require(ylnft.ownerOf(_tokenId) == msg.sender, "You haven't this token");
        require(ylnft.getApproved(_tokenId) == address(this), "NFT must be approved to market");
        
        ylnft.transferFrom(msg.sender, address(this), _tokenId);

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
                AuctionState.Active
            );
        }

        emit AdminSetBid(msg.sender, _period, _tokenId, 1, block.timestamp);

        return _auctionId;
    }

    //g.
    function bidBuyerNFT(uint256 _tokenId, uint256 _price, uint256 _period) public returns(uint256) {
        require(ylnft.ownerOf(_tokenId) == msg.sender, "You haven't this token");
        require(ylnft.getApproved(_tokenId) == address(this), "NFT must be approved to market");

        ylnft.transferFrom(msg.sender, address(this), _tokenId);

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
                AuctionState.Active
            );
        }

        emit UserSetBid(msg.sender, _period, _tokenId, 1, block.timestamp);
        return _auctionId;    
    }

    function userBidOffer(uint256 _auctionId, uint256 _price) public {
        require(ylnft.ownerOf(idToAuctionItem[_auctionId].tokenId) == address(this), "This token don't exist in market.");
        require(idToAuctionItem[_auctionId].auEnd > block.timestamp, "The bidding period has already passed.");
        require(idToAuctionItem[_auctionId].highestBid < _price, "The bid price must be higher than before.");
        idToAuctionItem[_auctionId].highestBid = _price;
        idToAuctionItem[_auctionId].highestBidder = msg.sender;

        emit UserBidoffer(msg.sender, _price, idToAuctionItem[_auctionId].tokenId, 1, _auctionId, block.timestamp);
    }

    function withdrawBid(uint256 _auctionId) public payable nonReentrant {
        require(ylnft.ownerOf(idToAuctionItem[_auctionId].tokenId) == address(this), "This token don't exist in market.");
        require(idToAuctionItem[_auctionId].auEnd < block.timestamp, "The bidding period have to pass.");
        require(idToAuctionItem[_auctionId].highestBidder == msg.sender, "The highest bidder can withdraw this token.");

        if(idToAuctionItem[_auctionId].owner == msg.sender) {
            require(msg.value >= marketfee, "insufficient fund");
            ylnft.transferFrom(address(this), msg.sender, idToAuctionItem[_auctionId].tokenId);
            emit BidNull(_auctionId, idToAuctionItem[_auctionId].tokenId, 1, msg.sender, block.timestamp);
        } else {
            require(msg.value >= idToAuctionItem[_auctionId].highestBid + marketfee, "Insufficient fund");
            ylnft.transferFrom(address(this), msg.sender, idToAuctionItem[_auctionId].tokenId);
            (bool sent,) = payable(idToAuctionItem[_auctionId].owner).call{value: idToAuctionItem[_auctionId].highestBid}("");
            require(sent, "Failed to send Ether to the seller");
            emit BidWinner(msg.sender, _auctionId, idToAuctionItem[_auctionId].tokenId, block.timestamp);
        }
    }
    
    //e. To transfer Direct
    function directTransferToBuyer(address _from, uint256 _tokenId, uint256 _price) public payable nonReentrant {
        uint256 startGas = gasleft();

        require(ylnft.ownerOf(_tokenId) == _from, "You haven't this NFT.");
        require(msg.value >= _price + marketfee, "Insufficient fund in marketplace");
        require(ylnft.getApproved(_tokenId) == address(this), "NFT must be approved to market");

        ylnft.transferFrom(_from, msg.sender, _tokenId);

        (bool sent,) = payable(_from).call{value: _price}("");
        require(sent, "Failed to send Ether");

        uint256 gasUsed = startGas - gasleft();
        emit UserNFTDirectTransferto(_from, _tokenId, msg.sender, _price, gasUsed, marketfee, block.timestamp);
    }

    //h. Pause
    function adminPauseToggle(MarketItem memory _item, bool _flag) public {
        uint256 _tokenId = _item.tokenId;
        require(ylnft.ownerOf(_tokenId) == address(this), "You haven't this tokenID.");
        require(_item.seller == msg.sender || marketplaceOwners[msg.sender] == true);
        if(_flag == true) {
            _item.state = State.Inactive;
            emit AdminPauselistedNFT(msg.sender, _tokenId, address(this), block.timestamp);
        } else {
            _item.state = State.Active;
            emit AdminUnpauselistedNFT(msg.sender, _tokenId, address(this), block.timestamp);
        }
    }

    //o.
    function adminTransfer(address _to, MarketItem memory _item) public payable ylOwners {
        require(ylnft.ownerOf(_item.tokenId) == address(this), "This contract haven't this NFT.");
        require(msg.value >= _item.price, "Insufficient fund.");
        uint256 _tokenId = _item.tokenId;
        ylnft.transferFrom(address(this), _to, _tokenId);
        (bool sent,) = payable(_item.seller).call{value: _item.price}("");
        require(sent, "Failed to send Ether");
        _item.owner = _to;
        _item.state = State.Release;

        emit AdminTransferNFT(msg.sender, _tokenId, 1, _to, block.timestamp);
    }

    // Purchased NFT
    function MarketItemSale(MarketItem memory _item) public payable nonReentrant returns(uint256) {
        uint256 startGas = gasleft();

        require(msg.value >= _item.price + marketfee, "insufficient fund");
        require(_item.seller != msg.sender, "This token is your NFT.");
        require(_item.owner == address(this), "This NFT don't exist in market");
        // require(ylnft.getApproved(_item.tokenId) == address(this), "NFT must be approved to market");

        ylnft.transferFrom(address(this), msg.sender, _item.tokenId);
        (bool sent,) = payable(_item.seller).call{value: _item.price}("");
        require(sent, "Failed to send Ether to the seller");
        _item.state = State.Release;
        _item.owner = msg.sender;

        uint256 gasUsed = startGas - gasleft();

        emit UserNFTtoMarketSold(_item.tokenId, _item.seller, _item.price, marketfee, block.timestamp);
        emit SoldNFT(_item.tokenId, 1, address(this), block.timestamp);
        emit PurchasedNFT(msg.sender, _item.tokenId, 1, _item.price, marketfee, gasUsed);

        return _item.tokenId;
    }

    //withdraw ether
    function withdrawEther(uint256 _amount) public ylOwners nonReentrant {
        require(address(this).balance >= _amount, "insufficient fund");
        (bool sent,) = payable(msg.sender).call{value: _amount}("");
        require(sent, "Failed to send Ether");
        emit AdminWithdrawFromEscrow(msg.sender, _amount, block.timestamp);
    }
}
