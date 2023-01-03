//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;
// pragma abicoder v2;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IProxy{
    function isMintableAccount(address _address) external view returns(bool);
    function isBurnAccount(address _address) external view returns(bool);
    function isTransferAccount(address _address) external view returns(bool);
    function isPauseAccount(address _address) external view returns(bool);
    function isSuperAdmin(address _address) external view returns(bool);
}

contract YL1155Marketplace is IERC1155Receiver,ReentrancyGuard{
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    
    IERC1155 public TokenX;

    IProxy public proxy;
    
    mapping(address => conductedAuctionList)conductedAuction;
     
    mapping(address => mapping(uint256 =>uint256))participatedAuction;
     
    mapping(address => histo)history;
     
    mapping(address => uint256[])collectedArts;
     
    struct histo{
        uint256[] list;
    }
     
    struct conductedAuctionList{
        uint256[] list;
    }
     
    //mapping(uint256 => auction)auctiondetails;
    
    //mapping(address => mapping(uint256 => uint256))biddersdetails;
    
    uint256 public auctionTime = uint256(5 days);   
    
    Counters.Counter private totalAuctionId;
    
    enum auctionStatus { ACTIVE, OVER }
    
    auction[] internal auctions;
    
    EnumerableSet.UintSet TokenIds;

    address payable market;
    
    address public vaultaddress;

    uint256 comission = 2 ;
    
    event AdminListedNFT1155(address user,uint256 nftid,uint256 quantity,uint256 price);
    event AdminUnlistedNFT1155(address user,uint256 nftid,uint256 price,uint256 timestamp);
    event AdminPauselistedNFT1155(address user,uint256 nftid,uint256 timestamp);
    event AdminUnpauselistedNFT1155(address user,uint256 nftid,uint256 timestamp);
    event PurchasedNFT1155(address user,uint256 boughtnftid,uint256 price,uint256 comission);
    event UserlistedNFTtoMarket1155(address user,uint256 nftid,uint256 price,uint256 timestamp);
    event UserNFTtoMarketSold1155(address user,uint256 nftid,uint256 price,uint256 comission);
    event UserNFTDirectTransferto1155(address fromaddress,uint256 nftid,address toaddress,uint256 price,uint256 comission,uint256 timestamp);
    event AdminWithdrawFromEscrow1155(address user,uint256 balance,address transferaddress,uint256 timestamp);
    event WithdrawNFTfromMarkettoWallet1155(uint256 id,address withdrawaddress,uint256 comission,uint256 timestamp);
    event TransferedNFTfromMarkettoVault1155(uint256 id,address vault,uint256 timestamp);
    event AdminTransferNFT1155(address admin,uint256 tokenid,address user,uint256 timestamp);
    event MarketCommissionSet1155(address admin,uint256 comissionfee,uint256 timestamp);
    event AdminSetBid1155(address admin,uint256 time,uint256 timestamp);
    event UserSetBid1155(address admin,uint256 time,uint256 timestamp);
    event BidWinner1155(address user,uint256 bidid,uint256 nftid,uint256 timestamp);

    struct auction{
        uint256 auctionId;
        uint256 amount;
        bytes data;
        uint256 start;
        uint256 end;
        uint256 tokenId;
        address auctioner;
        address highestBidder;
        uint256 highestBid;
        address[] prevBid;
        uint256[] prevBidAmounts;
        auctionStatus status;
    }
 
    constructor(IERC1155 _tokenx,IProxy _proxy){
        TokenX = _tokenx;
        proxy=_proxy;
    }
    
    mapping(uint256 => bool) public pauseStatus;

    function setVaultAddress(address _vaultaddress) public{
        require( proxy.isSuperAdmin(msg.sender) == true,'You are not superadmin');
        vaultaddress=_vaultaddress;
    }

    function setComission(uint256 _comission) public{
        require( proxy.isSuperAdmin(msg.sender) == true,'You are not superadmin');
        comission=_comission;
        emit MarketCommissionSet1155(msg.sender,_comission,block.timestamp);
    }

    function adminPause(uint256 _auctionid) public{
        require( proxy.isSuperAdmin(msg.sender) == true,'You are not superadmin');
        auction memory _auction= auctions[_auctionid];
        pauseStatus[_auctionid]=true;
        emit AdminPauselistedNFT1155(msg.sender,_auction.tokenId,block.timestamp);
    }

    function adminUnPause(uint256 _auctionid) public{
        require(proxy.isSuperAdmin(msg.sender) == true,'You are not superadmin');
        auction memory _auction= auctions[_auctionid];
        pauseStatus[_auctionid]=false;
        emit AdminUnpauselistedNFT1155(msg.sender,_auction.tokenId,block.timestamp);
    }
    function _ownerOf(uint256 tokenId) internal view returns (bool) {
        return TokenX.balanceOf(msg.sender, tokenId) != 0;
    }
    
    function adminAuction(uint256 _tokenId,uint256 _price,uint256 _time,uint256 amount,bytes memory data)public returns(uint256){
        require( proxy.isSuperAdmin(msg.sender) == true,'You are not superadmin');
	    require(_ownerOf(_tokenId) == true, "Auction your NFT");
	    
	    auction memory _auction = auction({
	    auctionId : totalAuctionId.current(),
        amount:amount,
        data:data,
        start: block.timestamp,
        end : block.timestamp + (_time * 86400),
        tokenId: _tokenId,
        auctioner: msg.sender,
        highestBidder: msg.sender,
        highestBid: _price,
        prevBid : new address[](0),
        prevBidAmounts : new uint256[](0),
        status: auctionStatus.ACTIVE
	    });
	    
	    conductedAuctionList storage list = conductedAuction[msg.sender];
	    list.list.push(totalAuctionId.current());
	    auctions.push(_auction);
	    TokenX.safeTransferFrom(address(msg.sender), address(this), _tokenId, amount, data);
	    emit AdminSetBid1155(msg.sender,_time,block.timestamp);
	    totalAuctionId.increment();
	    return uint256(totalAuctionId.current());
    }

     function userAuction(uint256 _tokenId,uint256 _price,uint256 _time,uint256 amount,bytes memory data)public returns(uint256){
	    require(_ownerOf(_tokenId) == true, "Auction your NFT");
	    
	    auction memory _auction = auction({
	    auctionId : totalAuctionId.current(),
        amount:amount,
        data:data,
        start: block.timestamp,
        end : block.timestamp + (_time * 86400),
        tokenId: _tokenId,
        auctioner: msg.sender,
        highestBidder: msg.sender,
        highestBid: _price,
        prevBid : new address[](0),
        prevBidAmounts : new uint256[](0),
        status: auctionStatus.ACTIVE
	    });
	    
	    conductedAuctionList storage list = conductedAuction[msg.sender];
	    list.list.push(totalAuctionId.current());
	    auctions.push(_auction);
        TokenX.safeTransferFrom(address(msg.sender), address(this), _tokenId, amount, data);
	    emit UserSetBid1155(msg.sender,_time,block.timestamp);
	    totalAuctionId.increment();
	    return uint256(totalAuctionId.current());
    }

    function adminListedNFT(uint256 _tokenId,uint256 _price,uint256 amount,bytes memory data) public returns(uint256){
        require( proxy.isSuperAdmin(msg.sender) == true,'You are not superadmin');
        require(_ownerOf(_tokenId) == true, "Auction your NFT");
        auction memory _auction = auction({
	    auctionId : totalAuctionId.current(),
        data:data,
        amount:amount,
        start: block.timestamp,
        end : block.timestamp + (auctionTime),
        tokenId: _tokenId,
        auctioner: msg.sender,
        highestBidder: msg.sender,
        highestBid: _price,
        prevBid : new address[](0),
        prevBidAmounts : new uint256[](0),
        status: auctionStatus.ACTIVE
	    });

        auctions.push(_auction);
	    TokenX.safeTransferFrom(address(msg.sender),address(this),_tokenId,amount,data);
	    
	    totalAuctionId.increment();
        emit AdminListedNFT1155(msg.sender,_tokenId,_price,amount);
	    return uint256(totalAuctionId.current());
    }

    function changePrice(uint256 _auctionId,uint256 price) public{
        auction storage auction = auctions[_auctionId];
        require(msg.sender == auction.auctioner,'You are not allowed' );
        auction.highestBid=price;
    }

    function buyAdminListedNFT(uint256 _auctionId) public {
        require(pauseStatus[_auctionId] ==false,'Auction id is paused');
        require(auctions[_auctionId].auctioner == msg.sender,"only auctioner");
        require(uint256(auctions[_auctionId].end) >= uint256(block.number),"already Finshed");
        
        auction storage auction = auctions[_auctionId];
        auction.end = uint32(block.number);
        auction.status = auctionStatus.OVER;

        uint256 marketFee = auction.highestBid * (comission) / (100);
        payable(msg.sender).transfer(auctions[_auctionId].highestBid - (marketFee));
        market.transfer(marketFee);
        TokenX.safeTransferFrom(address(this),auctions[_auctionId].highestBidder,auctions[_auctionId].tokenId,auctions[_auctionId].amount,"0x");
        emit PurchasedNFT1155(auctions[_auctionId].highestBidder,auction.tokenId,auctions[_auctionId].highestBid,marketFee);

    }

    
    function userListedNFT(uint256 _tokenId,uint256 _price,uint256 amount,bytes memory data) public returns(uint256){
        require(_ownerOf(_tokenId) == true, "Auction your NFT");
        auction memory _auction = auction({
	    auctionId : totalAuctionId.current(),
        amount:amount,
        data:data,
        start: block.timestamp,
        end : block.timestamp + (auctionTime),
        tokenId: _tokenId,
        auctioner: msg.sender,
        highestBidder: msg.sender,
        highestBid: _price,
        prevBid : new address[](0),
        prevBidAmounts : new uint256[](0),
        status: auctionStatus.ACTIVE
	    });

        auctions.push(_auction);
	    TokenX.safeTransferFrom(address(msg.sender),address(this),_tokenId,amount,data);
	    
	    totalAuctionId.increment();
        emit UserlistedNFTtoMarket1155(msg.sender,_tokenId,_price,block.timestamp);
	    return uint256(totalAuctionId.current());
    }

   

    function buyUserListedNFT(uint256 _auctionId) public {
        require(pauseStatus[_auctionId] ==false,'Auction id is paused');
        require(auctions[_auctionId].auctioner == msg.sender,"only auctioner");
        require(uint256(auctions[_auctionId].end) >= uint256(block.number),"already Finshed");
        
        auction storage auction = auctions[_auctionId];
        auction.end = uint32(block.number);
        auction.status = auctionStatus.OVER;

        uint256 marketFee = auction.highestBid * (comission) / (100);
        payable(msg.sender).transfer(auctions[_auctionId].highestBid - (marketFee));
        market.transfer(marketFee);
        TokenX.safeTransferFrom(address(this),auctions[_auctionId].highestBidder,auctions[_auctionId].tokenId,auctions[_auctionId].amount,auctions[_auctionId].data);
        emit UserNFTtoMarketSold1155(auctions[_auctionId].highestBidder,auction.tokenId,auctions[_auctionId].highestBid,marketFee);

    }

    function adminUnlistedNFT(uint256 _auctionId) public{
        require(pauseStatus[_auctionId] ==false,'Auction id is paused');
        require(auctions[_auctionId].auctioner == msg.sender,"only auctioner");
        require(uint256(auctions[_auctionId].end) >= uint256(block.number),"already Finshed");
        
        auction storage auction = auctions[_auctionId];
        emit AdminUnlistedNFT1155(msg.sender,auction.tokenId,auction.highestBid,block.timestamp);
        auction.end = uint32(block.number);
        auction.status = auctionStatus.OVER;
        auction.highestBid=0;
        auction.highestBidder=address(0);
        
        TokenX.safeTransferFrom(address(this),msg.sender,auctions[_auctionId].tokenId,auctions[_auctionId].amount,auctions[_auctionId].data);
       
    }
    
    function placeBid(uint256 _auctionId)public payable returns(bool){
        require(pauseStatus[_auctionId] ==false,'Auction id is paused');
        require(auctions[_auctionId].highestBid < msg.value,"Place a higher Bid");
        require(auctions[_auctionId].auctioner != msg.sender,"Not allowed");
        require(auctions[_auctionId].end > block.timestamp,"Auction Finished");
       
        auction storage auction = auctions[_auctionId];
        auction.prevBid.push(auction.highestBidder);
        auction.prevBidAmounts.push(auction.highestBid);
        if(participatedAuction[auction.highestBidder][_auctionId] > 0){
        participatedAuction[auction.highestBidder][_auctionId] = participatedAuction[auction.highestBidder][_auctionId] + (auction.highestBid); 
        }else{
            participatedAuction[auction.highestBidder][_auctionId] = auction.highestBid;
        }
        
        histo storage history = history[msg.sender];
        history.list.push(_auctionId);
        
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        return true;
    }
    
    function finishAuction(uint256 _auctionId) public{
        require(pauseStatus[_auctionId] ==false,'Auction id is paused');
        require(auctions[_auctionId].auctioner == msg.sender,"only auctioner");
        require(uint256(auctions[_auctionId].end) >= uint256(block.number),"already Finshed");
        
        auction storage auction = auctions[_auctionId];
        auction.end = uint32(block.number);
        auction.status = auctionStatus.OVER;
        
        uint256 marketFee = auction.highestBid * (comission) / (100);
        
        if(auction.prevBid.length > 0){
            
        for(uint256 i = 1; i < auction.prevBid.length; i++){
            if(participatedAuction[auctions[_auctionId].prevBid[i]][_auctionId] == auctions[_auctionId].prevBidAmounts[i] ){
            address payable give = payable(auctions[_auctionId].prevBid[i]);
            uint256 repay = auctions[_auctionId].prevBidAmounts[i];
            give.transfer(repay); 
            }
        }
        collectedArts[auctions[_auctionId].highestBidder].push(auctions[_auctionId].tokenId);
        payable(msg.sender).transfer(auctions[_auctionId].highestBid - (marketFee));
        market.transfer(marketFee);
        emit BidWinner1155(auctions[_auctionId].highestBidder,_auctionId,auctions[_auctionId].tokenId,block.timestamp);
        TokenX.safeTransferFrom(address(this),auctions[_auctionId].highestBidder,auctions[_auctionId].tokenId,auctions[_auctionId].amount,auctions[_auctionId].data);
        }
    
    }

    // function userNFTDirectTransferto(uint256 _tokenId,address _to) public{
    //      TokenX.safeTransferFrom(msg.sender,_to,_tokenId);
    //      emit userNFTDirectTransferto(msg.sender,_tokenId,_to,);
    // }

    function adminWithdrawFromEscrow(address payable _to) public nonReentrant{
        require( proxy.isSuperAdmin(msg.sender) == true,'You are not superadmin');
        emit AdminWithdrawFromEscrow1155(msg.sender,address(this).balance,_to,block.timestamp);
        _to.transfer(address(this).balance);
    }

    function adminWithdrawFromEscrow(uint256 amount) public nonReentrant{
          require( proxy.isSuperAdmin(msg.sender) == true,'You are not superadmin');
          payable(msg.sender).transfer(amount);
    }

    function withdrawNFTfromMarkettoWallet(uint256 _tokenId,address _to,uint256 amount,bytes memory data) public{
         payable(msg.sender).transfer(comission);
         TokenX.safeTransferFrom(address(this),_to,_tokenId,amount,data);
         emit WithdrawNFTfromMarkettoWallet1155(_tokenId,_to,comission,block.timestamp);
    }

    function transferedNFTfromMarkettoVault(uint256 _tokenId,address _vaultaddress,uint256 amount,bytes memory data) public{
         TokenX.safeTransferFrom(address(this),_vaultaddress,_tokenId,amount,data);
         emit TransferedNFTfromMarkettoVault1155(_tokenId,vaultaddress,block.timestamp);
    }

    function  adminTransferNFT(address _to,uint256 _tokenId,uint256 amount,bytes memory data) public{
        require( proxy.isSuperAdmin(msg.sender) == true,'You are not superadmin');
        emit AdminTransferNFT1155(msg.sender,_tokenId,_to,block.timestamp);
        TokenX.safeTransferFrom(msg.sender,_to,_tokenId,amount,data);
    }
    
    function auctionStatusCheck(uint256 _auctionId)public view returns(bool){
        if(auctions[_auctionId].end > block.timestamp)
        {
            return true;
        }
        else
        {
            return false;
        }
    }
    
    function auctionInfo(uint256 _auctionId)public view returns( uint256 auctionId,
        uint256 start,
        uint256 end,
        uint256 tokenId,
        address auctioner,
        address highestBidder,
        uint256 highestBid,
        uint256 status
    ){
            
        auction storage auction = auctions[_auctionId];
        auctionId = _auctionId;
        start = auction.start;
        end =auction.end;
        tokenId = auction.tokenId;
        auctioner = auction.auctioner;
        highestBidder = auction.highestBidder;
        highestBid = auction.highestBid;
        status = uint256(auction.status);
    }
        
    function bidHistory(uint256 _auctionId) public view returns(address[]memory,uint256[]memory){
        return (auctions[_auctionId].prevBid,auctions[_auctionId].prevBidAmounts);
    }
        
    function participatedAuctions(address _user) public view returns(uint256[]memory){
        return history[_user].list;
    }
    
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(TokenX), "received from unauthenticated contract");
        TokenIds.add(id);
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(TokenX), "received from unauthenticated contract");

        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

  function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
    return true;
  }
    
    function totalAuction() public view returns(uint256){
       return auctions.length;
    }
    
    function conductedAuctions(address _user)public view returns(uint256[]memory){
        return conductedAuction[_user].list;
    }
    
    function collectedArtsList(address _user)public view returns(uint256[] memory){
        return collectedArts[_user];
    }
}
