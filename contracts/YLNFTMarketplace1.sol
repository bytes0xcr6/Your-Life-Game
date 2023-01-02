//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./YLNFTMarketplace2.sol";

interface IProxy{
    function isMintableAccount(address _address) external view returns(bool);
    function isBurnAccount(address _address) external view returns(bool);
    function isTransferAccount(address _address) external view returns(bool);
    function isPauseAccount(address _address) external view returns(bool);
}

interface IVault{
    function transferToMarketplace(address market, address seller, uint256 _tokenId) external;
}

contract YLNFTMarketplace1 is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;

    IProxy public proxy;
    IERC721 public ylnft;
    
    address private nftmarket2 = 0x98d90a8666E02f5f0D0e4B48922EDbe7b0a810db;
    enum State { Active, Inactive, Release}

    struct MarketItem {
        uint256 itemId;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        State state;
    }

    event AdminListedNFT(address user, uint256 tokenId, uint256 price, uint256 timestamp);
    event UserlistedNFTtoMarket(address user, uint256 tokenId, uint256 price, address market, uint256 timestamp);
    event EscrowTransferFundsToSeller(address market, uint256 price, address user); //???
    event WithdrawNFTfromMarkettoWallet(uint256 tokenId, address user, uint256 commission, uint256 timestamp);
    event DepositNFTfromWallettoMarket(uint256 tokenId, address user, uint256 commission, uint256 timestamp);
    event TransferedNFTfromMarkettoVault(uint256 tokenId, address vault, uint256 timestamp);
    event TransferedNFTfromVaulttoMarket(uint256 tokenId, address vault, uint256 timestamp);
    event AdminApprovalNFTwithdrawtoWallet(address admin, uint256 tokenId, address user, uint256 commission, uint256 timestamp);
    event DepositNFTFromWallettoMarketApproval(uint256 tokenId, address user, uint256 commission, address admin, uint256 timestamp);
    event DepositNFTFromWallettoTeamsApproval(uint256 tokenId, address user, uint256 commission, address admin, uint256 timestamp);
    event RevertDepositFromWalletToTeams(uint256 tokenId, address user, address admin, uint256 timestamp);
    event RevertDepositFromWalletToMarket(uint256 tokenId, address user, address admin, uint256 timestamp);
    event MarketPerCommissionSet(address admin, uint256 commission, uint256 timestamp);

    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(address => mapping(uint256 => bool)) depositUsers;
    mapping(address => mapping(uint256 => bool)) withdrawUsers;
    mapping(address => mapping(uint256 => bool)) depositTeamUsers;

    modifier ylOwners() {
        require(YLNFTMarketplace2(nftmarket2).getOwner(msg.sender) == true, "You aren't the owner of marketplace");
        _;
    }

    constructor(IERC721 _ylnft, IProxy _proxy) {
        ylnft = _ylnft;
        proxy = _proxy;
    }

    //get itemId
    function getItemId() public view returns(uint256) {
        return _itemIds.current();
    }

    //get item data
    function getItem(uint256 _itemId) public view returns(MarketItem memory) {
        return idToMarketItem[_itemId];
    }

    //a. Minter listed NFT to Marketplace
    function minterListedNFT(uint256 _tokenId, uint256 _price) public returns(uint256) {
        require(ylnft.ownerOf(_tokenId) == msg.sender, "User haven't this token ID.");
        require(proxy.isMintableAccount(msg.sender), "You aren't Minter account");
        require(ylnft.getApproved(_tokenId) == address(this), "NFT must be approved to market");

        ylnft.transferFrom(msg.sender, address(this), _tokenId);

        uint256 _itemId = 0;
        for(uint i = 1; i <= _itemIds.current(); i++) {
            if(idToMarketItem[i].tokenId == _tokenId) {
                _itemId = idToMarketItem[i].itemId;
                break;
            }
        }

        if(_itemId == 0) {
            _itemIds.increment();
            _itemId = _itemIds.current();
            idToMarketItem[_itemId] = MarketItem(
                _itemId,
                _tokenId,
                msg.sender,
                address(this),
                _price,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(this);
            idToMarketItem[_itemId].seller = msg.sender;
            idToMarketItem[_itemId].price = _price;
        }

        emit AdminListedNFT(msg.sender, _tokenId, _price, block.timestamp);
        return _itemId;
    }

    //b. Buyer listed NFT to Marketplace
    function buyerListedNFT(uint256 _tokenId, uint256 _price) public payable returns(uint256) {
        require(ylnft.ownerOf(_tokenId) == msg.sender, "User haven't this token ID.");
        require(depositUsers[msg.sender][_tokenId] == true, "This token has not been approved by administrator.");
        require(ylnft.getApproved(_tokenId) == address(this), "NFT must be approved to market");
        require(msg.value >= YLNFTMarketplace2(nftmarket2).getMarketFee(), "Insufficient Fund.");

        ylnft.transferFrom(msg.sender, address(this), _tokenId);

        uint256 _itemId = 0;
        for(uint i = 1; i <= _itemIds.current(); i++) {
            if(idToMarketItem[i].tokenId == _tokenId) {
                _itemId = idToMarketItem[i].itemId;
                break;
            }
        }

        if(_itemId == 0) {
            _itemIds.increment();
            _itemId = _itemIds.current();
            idToMarketItem[_itemId] = MarketItem(
                _itemId,
                _tokenId,
                msg.sender,
                address(this),
                _price,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(this);
            idToMarketItem[_itemId].seller = msg.sender;
            idToMarketItem[_itemId].price = _price;
        }

        emit UserlistedNFTtoMarket(msg.sender, _tokenId, _price, address(this), block.timestamp);
        return _itemId;
    }

    //i. withdraw NFT
    function withdrawNFT721(uint256 itemId) public payable nonReentrant {
        uint256 _tokenId = idToMarketItem[itemId].tokenId;
        require(idToMarketItem[itemId].seller == msg.sender, "You haven't this NFT");
        require(msg.value >= YLNFTMarketplace2(nftmarket2).getMarketFee(), "insufficient fund");
        require(withdrawUsers[msg.sender][itemId] == true, "This token has not been approved by admin");
        ylnft.transferFrom(address(this), msg.sender, _tokenId);
        idToMarketItem[itemId].state = State.Release;
        idToMarketItem[itemId].owner = msg.sender;

        emit WithdrawNFTfromMarkettoWallet(_tokenId, msg.sender, YLNFTMarketplace2(nftmarket2).getMarketFee(), block.timestamp);
    }

    //j. deposit NFT
    function depositNFT721(uint256 _tokenId, uint256 _price) public payable returns(uint256) {
        require(ylnft.ownerOf(_tokenId) == msg.sender, "You haven't this NFT");
        require(msg.value >= YLNFTMarketplace2(nftmarket2).getMarketFee(), "Insufficient Fund.");
        require(depositUsers[msg.sender][_tokenId] == true, "This token has not been approved by admin.");
        require(ylnft.getApproved(_tokenId) == address(this), "NFT must be approved to market");

        ylnft.transferFrom(msg.sender, address(this), _tokenId);

        uint256 _itemId = 0;
        for(uint i = 1; i <= _itemIds.current(); i++) {
            if(idToMarketItem[i].tokenId == _tokenId) {
                _itemId = idToMarketItem[i].itemId;
                break;
            }
        }

        if(_itemId == 0) {
            _itemIds.increment();
            _itemId = _itemIds.current();
            idToMarketItem[_itemId] = MarketItem(
                _itemId,
                _tokenId,
                msg.sender,
                address(this),
                _price,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(this);
            idToMarketItem[_itemId].seller = msg.sender;
            idToMarketItem[_itemId].price = _price;
        }
        emit DepositNFTfromWallettoMarket(_tokenId, msg.sender, YLNFTMarketplace2(nftmarket2).getMarketFee(), block.timestamp);
        return _itemId;
    }

    // deposit approval from Admin
    function depositApproval(address _user, uint256 _tokenId, bool _flag) public ylOwners {
        require(ylnft.ownerOf(_tokenId) == _user, "The User aren't owner of this token.");
        depositUsers[_user][_tokenId] = _flag;
        if(_flag == true) {
            emit DepositNFTFromWallettoMarketApproval(_tokenId, _user, YLNFTMarketplace2(nftmarket2).getMarketFee(), msg.sender, block.timestamp);
        } else {
            emit RevertDepositFromWalletToMarket(_tokenId, _user, msg.sender, block.timestamp);
        }
    }

    // withdraw approval from Admin
    function withdrawApproval(address _user, uint256 _itemId, bool _flag) public ylOwners {
        require(idToMarketItem[_itemId].seller == _user, "You don't owner of this NFT.");
        require(ylnft.ownerOf(idToMarketItem[_itemId].tokenId) == address(this), "This token don't exist in market.");
        withdrawUsers[_user][_itemId] = _flag;
        if(_flag == true) {
            emit AdminApprovalNFTwithdrawtoWallet(msg.sender, idToMarketItem[_itemId].tokenId, _user, YLNFTMarketplace2(nftmarket2).getMarketFee(), block.timestamp);
        }
    }

    //k. To transfer the NFTs to his team(vault)
    function transferToVault(uint256 _itemId, address _vault) public nonReentrant returns(uint256) {
        uint256 _tokenId = idToMarketItem[_itemId].tokenId;
        require(ylnft.ownerOf(_tokenId) == address(this), "This token didn't list on marketplace");
        require(idToMarketItem[_itemId].seller == msg.sender, "You don't owner of this token");
        require(depositTeamUsers[msg.sender][_itemId] == true, "This token has not been approved by admin");
        
        ylnft.transferFrom(address(this), _vault, _tokenId);
        idToMarketItem[_itemId].state = State.Release;
        idToMarketItem[_itemId].owner = _vault;

        emit TransferedNFTfromMarkettoVault(_tokenId, _vault, block.timestamp);
        return _tokenId;
    }

    // team approval
    function depositTeamApproval(address _user, uint256 _itemId, bool _flag) public ylOwners {
        require(ylnft.ownerOf(idToMarketItem[_itemId].tokenId) == address(this), "This token don't exist in market");
        require(idToMarketItem[_itemId].seller == _user, "The user isn't the owner of token");
        depositTeamUsers[_user][_itemId] = _flag;
        if(_flag == true) {
            emit DepositNFTFromWallettoTeamsApproval(idToMarketItem[_itemId].tokenId, _user, YLNFTMarketplace2(nftmarket2).getMarketFee(), msg.sender, block.timestamp);
        } else {
            emit RevertDepositFromWalletToTeams(idToMarketItem[_itemId].tokenId, _user, msg.sender, block.timestamp);
        }
    }

    //l. transfer from vault to marketplace
    function transferFromVaultToMarketplace(uint256 _tokenId, address _vault, uint256 _price) public {
        require(ylnft.ownerOf(_tokenId) == _vault, "The team haven't this token.");
        IVault vault = IVault(_vault);
        vault.transferToMarketplace(address(this), msg.sender, _tokenId);// Implement this function in the Vault Contract.

        uint256 _itemId = 0;
        for(uint i = 1; i <= _itemIds.current(); i++) {
            if(idToMarketItem[i].tokenId == _tokenId) {
                _itemId = idToMarketItem[i].itemId;
                break;
            }
        }

        if(_itemId == 0) {
            _itemIds.increment();
            _itemId = _itemIds.current();
            idToMarketItem[_itemId] = MarketItem(
                _itemId,
                _tokenId,
                msg.sender,
                address(this),
                _price,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(this);
            idToMarketItem[_itemId].seller = msg.sender;
        }

        emit TransferedNFTfromVaulttoMarket(_tokenId, _vault, block.timestamp);
    }

    // Marketplace Listed unpaused NFTs
    function fetchMarketItems() public view returns(MarketItem[] memory) {
        uint256 total = _itemIds.current();
        
        uint256 itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if(idToMarketItem[i].state == State.Active && idToMarketItem[i].owner == address(this) && ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) {
                itemCount++;
            }
        }
        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if(idToMarketItem[i].state == State.Active && idToMarketItem[i].owner == address(this) && ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) {
                items[index] = idToMarketItem[i];
                index++;
            }
        }

        return items;
    }
    
    
     // Marketplace Listed paused NFTs
    function fetchMarketPausedItems() public view returns(MarketItem[] memory) {
        uint256 total = _itemIds.current();
        
        uint256 itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if(idToMarketItem[i].state == State.Inactive && idToMarketItem[i].owner == address(this) && ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) {
                itemCount++;
            }
        }
        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if(idToMarketItem[i].state == State.Inactive && idToMarketItem[i].owner == address(this) && ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) {
                items[index] = idToMarketItem[i];
                index++;
            }
        }

        return items;
    }
    
    // My listed but paused NFTs
    function fetchMyPausedItems() public view returns(MarketItem[] memory) {
        uint256 total = _itemIds.current();

        uint itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if( idToMarketItem[i].state == State.Inactive 
                && idToMarketItem[i].seller == msg.sender
                && idToMarketItem[i].owner == address(this)
                && (ylnft.getApproved(idToMarketItem[i].tokenId) == address(this))) {
                
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if( idToMarketItem[i].state == State.Inactive 
                && idToMarketItem[i].seller == msg.sender
                && idToMarketItem[i].owner == address(this)
                && (ylnft.getApproved(idToMarketItem[i].tokenId) == address(this))) {
                
                items[index] = idToMarketItem[i];
                index++;
            }
        }

        return items;
    }


    // My listed NFTs
    function fetchMyItems() public view returns(MarketItem[] memory) {
        uint256 total = _itemIds.current();

        uint itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if( idToMarketItem[i].state == State.Active 
                && idToMarketItem[i].seller == msg.sender
                && idToMarketItem[i].owner == address(this)
                && ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) {
                
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if( idToMarketItem[i].state == State.Active 
                && idToMarketItem[i].seller == msg.sender
                && idToMarketItem[i].owner == address(this)
                && ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) {
                
                items[index] = idToMarketItem[i];
                index++;
            }
        }

        return items;
    }
}
