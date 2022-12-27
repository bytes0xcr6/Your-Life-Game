//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./YLT.sol";

interface IProxy{
    function isMintableAccount(address _address) external view returns(bool);
    function isBurnAccount(address _address) external view returns(bool);
    function isTransferAccount(address _address) external view returns(bool);
    function isPauseAccount(address _address) external view returns(bool);
}

interface IVault{
    function transferToMarketplace(address market, address seller, uint256 _tokenId, uint256 _amount) external;
}


contract YLNFTMarketplace is ERC1155Holder, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;

    IProxy public proxy;
    IERC721 public ylnft721;
    IERC1155 public ylnft1155;
    IERC20 public ylt20;
    
    address public _marketplaceOwner;
    uint256 public marketfee = 1;
    uint256 public marketcommission = 5; // = 5%

    enum State { Active, Inactive, Release}

    struct MarketItem {
        uint256 itemId;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        uint256 amount;
        bool isERC721;
        State state;
    }

    event AdminListedNFT(address user, uint256 tokenId, uint256 price, uint256 amount, uint256 timestamp);
    event UserlistedNFTtoMarket(address user, uint256 tokenId, uint256 price, uint256 amount, address market, uint256 timestamp);
    event UserNFTDirectTransferto(address user, uint256 tokenId, address to, uint256 price, uint256 amount, uint256 gas, uint256 commission, uint256 timestamp);
    event AdminPauselistedNFT(address user, uint256 tokenId, address marketplace, uint256 timestamp);
    event AdminUnpauselistedNFT(address user, uint256 tokenId, uint256 amount, address marketplace, uint256 timestamp);
    event PurchasedNFT(address user, uint256 tokenId, uint256 amount, uint256 price, uint256 commission);
    event SoldNFT(uint256 tokenId, uint256 amount, address market, uint256 timestamp);
    event UserNFTtoMarketSold(uint256 tokenId, address user, uint256 price, uint256 amount, uint256 commission, uint256 timestamp);
    event AdminWithdrawFromEscrow(address admin, uint256 amount, uint256 timestamp);
    event EscrowTransferFundsToSeller(address market, uint256 price, address user); //???
    event WithdrawNFTfromMarkettoWallet(uint256 tokenId, address user, uint256 amount, uint256 commission, uint256 timestamp);
    event TransferedNFTfromMarkettoVault(uint256 tokenId, address vault, uint256 amount, uint256 timestamp);
    event TransferedNFTfromVaulttoMarket(uint256 tokenId, address vault, uint256 amount, uint256 timestamp);
    event AdminApprovalNFTwithdrawtoWallet(address admin, uint256 tokenId, address user, uint256 amount, uint256 commission, uint256 timestamp);
    event DepositNFTFromWallettoMarketApproval(uint256 tokenId, address user, uint256 amount, uint256 commission, address admin, uint256 timestamp);
    event RevertDepositFromWalletToMarket(uint256 tokenId, address user, uint256 amount, address admin, uint256 timestamp);
    event DepositNFTFromWallettoTeamsApproval(uint256 tokenId, address user, uint256 amount, uint256 commission, address admin, uint256 timestamp);
    event RevertDepositFromWalletToTeams(uint256 tokenId, address user, uint256 amount, address admin, uint256 timestamp);
    event AdminTransferNFT(address admin, uint256 tokenId, uint256 amount, address user, uint256 timestamp);
    event MarketPerCommissionSet(address admin, uint256 commission, uint256 timestamp);
    event MarketVCommisionSet(address admin, uint256 commission, uint256 timestamp);
    event MarketItemEditted(address user, uint256 tokenId, uint256 price, uint256 timestamp);

    mapping(address => bool) public marketplaceOwners;
    mapping(uint256 => MarketItem) public idToMarketItem;
    mapping(address => mapping(uint256 => bool)) depositUsers;
    mapping(address => mapping(uint256 => bool)) withdrawUsers;
    mapping(address => mapping(uint256 => bool)) depositTeamUsers;

    modifier ylOwners() {
        require(marketplaceOwners[msg.sender] == true, "You aren't the owner of marketplace");
        _;
    }

    constructor(IERC721 _ylnft721, IERC1155 _ylnft1155, address _ylt20, IProxy _proxy) {
        ylnft721 = _ylnft721;
        ylnft1155 = _ylnft1155;
        ylt20 = IERC20(_ylt20);
        proxy = _proxy;
        _marketplaceOwner = msg.sender;
        marketplaceOwners[msg.sender] = true;
    }

    function isMarketOwner() public view returns(bool) {
        return marketplaceOwners[tx.origin];
    }

    //get itemId
    function getItemId() public view returns(uint256) {
        return _itemIds.current();
    }

    //get item data
    function getItem(uint256 _itemId) public view returns(MarketItem memory) {
        return idToMarketItem[_itemId];
    }

    //get owner
    function getOwner(address _owner) public view returns(bool) {
        return marketplaceOwners[_owner];
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

    //c. Marketplace Credential
    function allowCredential(address _mOwner, bool _flag) public ylOwners returns(bool) {
        marketplaceOwners[_mOwner] = _flag;
        return true;
    }

    //a. Minter listed NFT to Marketplace
    function minterListedNFT(uint256 _tokenId, uint256 _price, uint256 _amount, bool _isERC721) public returns(uint256) {
        require(proxy.isMintableAccount(msg.sender), "You aren't Minter account");
        if (_isERC721 == true){
            require(ylnft721.getApproved(_tokenId) == address(this), "NFT must be approved to market");

            ylnft721.transferFrom(msg.sender, address(this), _tokenId);
        }
        else{
            require(ylnft1155.isApprovedForAll(msg.sender, address(this)) == true, "NFT must be approved to market");

            ylnft1155.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");
        }

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
                _amount,
                _isERC721,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(this);
            idToMarketItem[_itemId].seller = msg.sender;
            idToMarketItem[_itemId].price = _price;
            idToMarketItem[_itemId].isERC721 = _isERC721;
            if(_isERC721)
                idToMarketItem[_itemId].amount = _amount;
            else
                idToMarketItem[_itemId].amount += _amount;
        }

        emit AdminListedNFT(msg.sender, _tokenId, _price, _amount, block.timestamp);
        return _itemId;
    }

    //b. Buyer listed NFT to Marketplace
    function buyerListedNFT(uint256 _tokenId, uint256 _price, uint256 _amount, bool _isERC721) public returns(uint256) {
        bool isTransferred;
        if(_isERC721){
            require(ylnft721.ownerOf(_tokenId) == msg.sender, "User haven't this token ID.");
            require(ylnft721.getApproved(_tokenId) == address(this), "NFT must be approved to market");
            (isTransferred) = ylt20.transferFrom(msg.sender, address(this), marketfee);
            require(isTransferred, "Insufficient Fund.");

            ylnft721.transferFrom(msg.sender, address(this), _tokenId);
        }
        else{
            require(ylnft1155.balanceOf(msg.sender, _tokenId) >= _amount, "User haven't this token ID.");
            require(ylnft1155.isApprovedForAll(msg.sender, address(this)) == true, "NFT must be approved to market");
            (isTransferred) = ylt20.transferFrom(msg.sender, address(this), marketfee);
            require(isTransferred, "Insufficient Fund.");

            ylnft1155.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");
        }
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
                _amount,
                _isERC721,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(this);
            idToMarketItem[_itemId].seller = msg.sender;
            idToMarketItem[_itemId].price = _price;
            idToMarketItem[_itemId].isERC721 = _isERC721;
            if(_isERC721)
                idToMarketItem[_itemId].amount = _amount;
            else
                idToMarketItem[_itemId].amount += _amount;
        }

        emit UserlistedNFTtoMarket(msg.sender, _tokenId, _price, _amount, address(this), block.timestamp);
        return _itemId;
    }

    //e. To transfer Direct
    function directTransferToBuyer(address _from, uint256 _tokenId, uint256 _price, uint256 _amount, bool _isERC721) public nonReentrant {
        uint256 startGas = gasleft();
        if(_isERC721){
            require(ylnft721.ownerOf(_tokenId) == _from, "You haven't this NFT.");
            (bool isTransferred) = ylt20.transferFrom(msg.sender, address(this), _price + marketfee);
            require(isTransferred, "Insufficient Fund.");
            require(ylnft721.getApproved(_tokenId) == address(this), "NFT must be approved to market");

            ylnft721.transferFrom(_from, msg.sender, _tokenId);

            isTransferred = ylt20.transfer(_from, _price);
            require(isTransferred, "Failed to send token");

            uint256 gasUsed = startGas - gasleft();
            emit UserNFTDirectTransferto(_from, _tokenId, msg.sender, _price, 1, gasUsed, marketfee, block.timestamp);
        }
        else{
            require(ylnft1155.balanceOf(_from, _tokenId) >= _amount, "You haven't this NFT.");
            (bool isTransferred) = ylt20.transferFrom(msg.sender, address(this), _price * _amount + marketfee);
            require(isTransferred, "Insufficient Fund.");
            require(ylnft1155.isApprovedForAll(_from, address(this)) == true, "NFT must be approved to market");

            ylnft1155.safeTransferFrom(_from, msg.sender, _tokenId, _amount, "");

            (isTransferred) = ylt20.transfer(_from, _price * _amount);
            require(isTransferred, "Failed to send token");

            uint256 gasUsed = startGas - gasleft();
            emit UserNFTDirectTransferto(_from, _tokenId, msg.sender, _price, _amount, gasUsed, marketfee, block.timestamp);
        }
    }

    //h. Pause
    function adminPauseToggle(uint256 _itemId, uint256 _amount, bool _flag) public ylOwners{
        uint256 _tokenId = idToMarketItem[_itemId].tokenId;
        require(ylnft721.ownerOf(_tokenId) == address(this) || ylnft1155.balanceOf(address(this), idToMarketItem[_itemId].tokenId) >= idToMarketItem[_itemId].amount, "You haven't this tokenID.");
        require(idToMarketItem[_itemId].seller == msg.sender || marketplaceOwners[msg.sender] == true);
        if(_flag == true) {
            idToMarketItem[_itemId].state = State.Inactive;
            emit AdminPauselistedNFT(msg.sender, _tokenId, address(this), block.timestamp);
        } else {
            idToMarketItem[_itemId].state = State.Active;
            emit AdminUnpauselistedNFT(msg.sender, _tokenId, _amount, address(this), block.timestamp);
        }
    }

    //i. withdraw NFT
    function withdrawNFT(uint256 itemId, uint256 _amount, bool _isERC721) public nonReentrant {
        uint256 _tokenId = idToMarketItem[itemId].tokenId;
        require(idToMarketItem[itemId].seller == msg.sender, "You haven't this NFT");
        (bool isTransferred) = ylt20.transferFrom(msg.sender, address(this), marketfee);
        require(isTransferred, "Insufficient Fund.");
        require(withdrawUsers[msg.sender][itemId] == true, "This token has not been approved by admin");
        if(_isERC721){
            ylnft721.transferFrom(address(this), msg.sender, _tokenId);
            idToMarketItem[itemId].state = State.Release;
            idToMarketItem[itemId].owner = msg.sender;
        }
        else{
            ylnft1155.safeTransferFrom(address(this), msg.sender, _tokenId, _amount, "");
            if(idToMarketItem[itemId].amount == _amount){
                idToMarketItem[itemId].state = State.Release;
                idToMarketItem[itemId].owner = msg.sender;
            }
            else{
                idToMarketItem[itemId].amount -= _amount;
            }
        }
        emit WithdrawNFTfromMarkettoWallet(_tokenId, msg.sender, _amount, marketfee, block.timestamp);
    }

    //j. deposit NFT
    function depositNFT(uint256 _tokenId, uint256 _amount, uint256 _price, bool _isERC721) public returns(uint256) {
        require(ylnft721.ownerOf(_tokenId) == msg.sender || ylnft1155.balanceOf(msg.sender, _tokenId) >= _amount, "You haven't this NFT");
        (bool isTransferred) = ylt20.transferFrom(msg.sender, address(this), marketfee);
        require(isTransferred, "Insufficient Fund.");
        require(ylnft721.getApproved(_tokenId) == address(this) || ylnft1155.isApprovedForAll(msg.sender, address(this)) == true, "NFT must be approved to market");

        if(_isERC721)
            ylnft721.transferFrom(msg.sender, address(this), _tokenId);
        else
            ylnft1155.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");

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
                _amount,
                _isERC721,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(this);
            idToMarketItem[_itemId].seller = msg.sender;
            idToMarketItem[_itemId].price = _price;
            idToMarketItem[_itemId].isERC721 = _isERC721;
            if(_isERC721)
                idToMarketItem[_itemId].amount = _amount;
            else
                idToMarketItem[_itemId].amount += _amount;
        }

        return _itemId;
    }

    // deposit approval from Admin
    function depositApproval(address _user, uint256 _tokenId, uint256 _amount, bool _flag) public ylOwners {
        require(ylnft721.ownerOf(_tokenId) == _user || ylnft1155.balanceOf(_user, _tokenId) >= _amount, "The User aren't owner of this token.");
        depositUsers[_user][_tokenId] = _flag;
        if(_flag == true) {
            emit DepositNFTFromWallettoMarketApproval(_tokenId, _user, _amount, marketfee, msg.sender, block.timestamp);
        } else {
            emit RevertDepositFromWalletToMarket(_tokenId, _user, _amount, msg.sender, block.timestamp);
        }
    }

    // withdraw approval from Admin
    function withdrawApproval(address _user, uint256 _itemId, uint256 _amount, bool _flag) public ylOwners {
        require(idToMarketItem[_itemId].seller == _user, "You don't owner of this NFT.");
        require(ylnft721.ownerOf(idToMarketItem[_itemId].tokenId) == address(this) || ylnft1155.balanceOf(address(this), idToMarketItem[_itemId].tokenId) >= _amount , "This token don't exist in market.");
        withdrawUsers[_user][_itemId] = _flag;
        if(_flag == true) {
            emit AdminApprovalNFTwithdrawtoWallet(msg.sender, idToMarketItem[_itemId].tokenId, _user, _amount, marketfee, block.timestamp);
        }
    }

    //k. To transfer the NFTs to his team(vault)
    function transferToVault(uint256 _itemId, uint256 _amount, address _vault, bool _isERC721) public nonReentrant returns(uint256) {
        uint256 _tokenId = idToMarketItem[_itemId].tokenId;
        require(ylnft721.ownerOf(_tokenId) == address(this) || ylnft1155.balanceOf(address(this), _tokenId) >= _amount, "This token didn't list on marketplace");
        require(idToMarketItem[_itemId].seller == msg.sender, "You don't owner of this token");
        require(depositTeamUsers[msg.sender][_itemId] == true, "This token has not been approved by admin");
        
        if(_isERC721){
            ylnft721.transferFrom(address(this), _vault, _tokenId);
            idToMarketItem[_itemId].state = State.Release;
            idToMarketItem[_itemId].owner = _vault;
        }
        else{
            ylnft1155.safeTransferFrom(address(this), _vault, _tokenId, _amount, "");
            if(idToMarketItem[_itemId].amount == _amount){
                idToMarketItem[_itemId].state = State.Release;
                idToMarketItem[_itemId].owner = _vault;
            }
            else
                idToMarketItem[_itemId].amount -= _amount;
        }
        emit TransferedNFTfromMarkettoVault(_tokenId, _vault, _amount, block.timestamp);
        return _tokenId;
    }

    // team approval
    function depositTeamApproval(address _user, uint256 _itemId, uint256 _amount, bool _flag) public ylOwners {
        require(ylnft721.ownerOf(idToMarketItem[_itemId].tokenId) == address(this) || ylnft1155.balanceOf(address(this), idToMarketItem[_itemId].tokenId) >= _amount, "This token don't exist in market");
        require(idToMarketItem[_itemId].seller == _user, "The user isn't the owner of token");
        depositTeamUsers[_user][_itemId] = _flag;
        if(_flag == true) {
            emit DepositNFTFromWallettoTeamsApproval(idToMarketItem[_itemId].tokenId, _user, _amount, marketfee, msg.sender, block.timestamp);
        } else {
            emit RevertDepositFromWalletToTeams(idToMarketItem[_itemId].tokenId, _user, _amount, msg.sender, block.timestamp);
        }
    }

    //l. transfer from vault to marketplace
    function transferFromVaultToMarketplace(uint256 _tokenId, address _vault, uint256 _price, uint256 _amount, bool _isERC721) public {
        require(ylnft721.ownerOf(_tokenId) == _vault || ylnft1155.balanceOf(_vault, _tokenId) >= _amount, "The team haven't this token.");
        IVault vault = IVault(_vault);
        vault.transferToMarketplace(address(this), msg.sender, _tokenId, _amount);// Implement this function in the Vault Contract.

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
                _amount,
                _isERC721,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(this);
            idToMarketItem[_itemId].seller = msg.sender;
            idToMarketItem[_itemId].isERC721 = _isERC721;
            if(_isERC721)
                idToMarketItem[_itemId].amount = _amount;
            else
                idToMarketItem[_itemId].amount += _amount;
        }

        emit TransferedNFTfromVaulttoMarket(_tokenId, _vault, _amount, block.timestamp);
    }

    //o.
    function adminTransfer(address _to, uint256 _itemId, uint256 _amount, bool _isERC721) public ylOwners {
        require(ylnft721.ownerOf(idToMarketItem[_itemId].tokenId) == address(this) || ylnft1155.balanceOf(address(this), idToMarketItem[_itemId].tokenId) >= _amount, "This contract haven't this NFT.");
        (bool isTransferred) = ylt20.transferFrom(msg.sender, address(this), idToMarketItem[_itemId].price);
        require(isTransferred, "Insufficient Fund.");
        uint256 _tokenId = idToMarketItem[_itemId].tokenId;
        if(_isERC721)
            ylnft721.transferFrom(address(this), _to, _tokenId);
        else
            ylnft1155.safeTransferFrom(address(this), _to, _itemId, _amount, "");
        (isTransferred) = ylt20.transfer(idToMarketItem[_itemId].seller, idToMarketItem[_itemId].price);
        require(isTransferred, "Failed to send token");
        if(_isERC721){
            idToMarketItem[_itemId].owner = _to;
            idToMarketItem[_itemId].state = State.Release;
        }
        else{
            if(idToMarketItem[_itemId].amount == _amount){
                idToMarketItem[_itemId].owner = _to;
                idToMarketItem[_itemId].state = State.Release;
            }
            else{
                idToMarketItem[_itemId].amount -= _amount;
            }
        }

        emit AdminTransferNFT(msg.sender, _tokenId, _amount, _to, block.timestamp);
    }

    // Marketplace Listed NFTs
    function fetchMarketItems() public view returns(MarketItem[] memory) {
        uint256 total = _itemIds.current();
        
        uint256 itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if((idToMarketItem[i].state == State.Active || idToMarketItem[i].state == State.Inactive) && idToMarketItem[i].owner == address(this)) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if((idToMarketItem[i].state == State.Active || idToMarketItem[i].state == State.Inactive) && idToMarketItem[i].owner == address(this)) {
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
            if( (idToMarketItem[i].state == State.Active || idToMarketItem[i].state == State.Inactive) 
                && idToMarketItem[i].seller == msg.sender
                && idToMarketItem[i].owner == address(this)) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if( (idToMarketItem[i].state == State.Active || idToMarketItem[i].state == State.Inactive) 
                && idToMarketItem[i].seller == msg.sender
                && idToMarketItem[i].owner == address(this)) {
                items[index] = idToMarketItem[i];
                index++;
            }
        }
        return items;
    }

    // Purchased NFT
    function MarketItemSale(uint256 itemId, uint256 _amount, bool _isERC721) public nonReentrant returns(uint256) {
        (bool isTransferred) = ylt20.transferFrom(msg.sender, address(this), idToMarketItem[itemId].price + marketfee);
        require(isTransferred, "Insufficient Fund.");
        require(idToMarketItem[itemId].seller != msg.sender, "This token is your NFT.");
        require(idToMarketItem[itemId].owner == address(this), "This NFT don't exist in market");
        if(_isERC721)
            ylnft721.transferFrom(address(this), msg.sender, idToMarketItem[itemId].tokenId);
        else
            ylnft1155.safeTransferFrom(address(this), msg.sender, idToMarketItem[itemId].tokenId, _amount, "");
        (isTransferred) = ylt20.transfer(idToMarketItem[itemId].seller, idToMarketItem[itemId].price);
        require(isTransferred, "Failed to send Ether to the seller");
        if(_isERC721){
            idToMarketItem[itemId].state = State.Release;
            idToMarketItem[itemId].owner = msg.sender;
        }
        else{
            if(idToMarketItem[itemId].amount == _amount){
                idToMarketItem[itemId].state = State.Release;
                idToMarketItem[itemId].owner = msg.sender;
            }
            else
                idToMarketItem[itemId].amount -= _amount;
        }

        emit UserNFTtoMarketSold(idToMarketItem[itemId].tokenId, idToMarketItem[itemId].seller, idToMarketItem[itemId].price, _amount, marketfee, block.timestamp);
        emit SoldNFT(idToMarketItem[itemId].tokenId, _amount, address(this), block.timestamp);
        emit PurchasedNFT(msg.sender, idToMarketItem[itemId].tokenId, _amount, idToMarketItem[itemId].price, marketfee);

        return idToMarketItem[itemId].tokenId;
    }

    //withdraw token
    function withdrawToken(uint256 _amount) public ylOwners nonReentrant {
        require(ylt20.balanceOf(address(this)) >= _amount, "insufficient fund");
        (bool sent) = ylt20.transfer(msg.sender, _amount);
        require(sent, "Failed to send token");
        emit AdminWithdrawFromEscrow(msg.sender, _amount, block.timestamp);
    }

    function editMarketItem(uint256 _itemId, uint256 _price) public {
        require(idToMarketItem[_itemId].state == State.Active, "This item is not active on marketplace");
        require(idToMarketItem[_itemId].seller == msg.sender, "You can't edit this market item");
        idToMarketItem[_itemId].price = _price;
        emit MarketItemEditted(msg.sender, idToMarketItem[_itemId].tokenId, _price, block.timestamp);
    }
}