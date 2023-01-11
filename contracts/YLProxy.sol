//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract YLProxy is ReentrancyGuard, Ownable {
    address public _ylOwner;
    address public prevadmin;
    address private marketNFTAddress1;
    address private marketNFTAddress2;
    address private marketERC1155Address;
    address private ylVault;
    address private auctionAddress;
    address private nftAddress;
    uint256 public sufficientstakeamount;
    bool public paused;

    IERC20 public ylt;

    constructor(address _yltAddress) {
        _ylOwner = msg.sender;
        sufficientstakeamount = 100 * 10**18;
        ylt = IERC20(_yltAddress);
        mintableAccounts[msg.sender] = true;
        burnableAccounts[msg.sender] = true;
        pausableAccounts[msg.sender] = true;
        transferableAccounts[msg.sender] = true;
    }

    mapping(address => mapping(address => uint256)) public stakedAmount;
    mapping(address => bool) public mintableAccounts;
    mapping(address => bool) public burnableAccounts;
    mapping(address => bool) public pausableAccounts;
    mapping(address => bool) public transferableAccounts;
    mapping(address => bool) public isAthlete;
    mapping(address => bool) public athleteMinted;

    //events
    event DepositStake(
        address indexed stakedUser,
        uint256 amount,
        address stakedContract,
        address tokenContract
    );
    event WithdrawStake(
        address indexed withdrawUser,
        uint256 amount,
        address withdrawContract,
        address tokenContract
    );
    event GrantACLto(
        address indexed _superadmin,
        address indexed admin,
        uint256 timestamp
    );
    event RemoveACLfrom(
        address indexed _superadmin,
        address indexed admin,
        uint256 timestamp
    );
    event AtheleteSet(
        address indexed _superadmin,
        address indexed admin,
        uint256 timestamp
    );
    event RemovedAthelete(
        address indexed _superadmin,
        address indexed admin,
        uint256 timestamp
    );

    //YLT token address
    function setYLTAddress(address _yltToken)
        external
        onlyOwner
        returns (bool)
    {
        ylt = IERC20(_yltToken);
        return true;
    }

    // ERC721 NFT address
    function setNFTAddress(address _nftAddress)
        external
        onlyOwner
        returns (bool)
    {
        nftAddress = _nftAddress;
        return true;
    }

    // NFT Market place 1
    function setMarketNFTAddress1(address _marketAddress)
        public
        onlyOwner
    {
        marketNFTAddress1 = _marketAddress;
    }

    // NFT Market place 2
    function setMarketNFTAddress2(address _marketAddress)
        public
        onlyOwner
    {
        marketNFTAddress2 = _marketAddress;
    }

    // Auction address
    function setAuctionAddress(address _auctionAddress) public onlyOwner{
        auctionAddress = _auctionAddress;
    }

    // YLVault address
    function setYLVault(address _ylVault) public onlyOwner {
        ylVault = _ylVault;
    }

    // ERC1155 market place 
    function setERC1155Market(address _marketERC1155Address) public onlyOwner {
        marketERC1155Address  = _marketERC1155Address;  
    }
    
    //sufficient Amount
    function setSufficientAmount(uint256 _amount)
        public
        onlyOwner
        returns (bool)
    {
        sufficientstakeamount = _amount;
        return true;
    }

    //deposit
    function depositYLT(uint256 _amount) public {
        require(ylt.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        require(
            ylt.allowance(msg.sender, address(this)) >= _amount,
            "Insufficient allowance"
        );
        ylt.transferFrom(msg.sender, address(this), _amount);
        stakedAmount[msg.sender][address(ylt)] += _amount;
        emit DepositStake(msg.sender, _amount, address(this), address(ylt));
    }

    //withdraw
    function withdrawYLT(address _to, uint256 _amount)
        public
        onlyOwner
        nonReentrant
    {
        require(
            stakedAmount[_to][address(ylt)] >= _amount,
            "Insufficient staked amount"
        );
        stakedAmount[_to][address(ylt)] -= _amount;
        ylt.transfer(_to, _amount);
        emit WithdrawStake(_to, _amount, address(this), address(ylt));
    }

    function changeSuperAdmin(address _superadmin) external onlyOwner {
        _ylOwner = _superadmin;
    }

    //mintable
    function accessMint(address _address, bool _value) public onlyOwner {
        if (_value == true) {
            mintableAccounts[_address] = _value;
            emit GrantACLto(msg.sender, _address, block.timestamp);
        } else {
            mintableAccounts[_address] = _value;
            emit RemoveACLfrom(msg.sender, _address, block.timestamp);
        }
    }

    //burnable
    function accessBurn(address _address, bool _value) public onlyOwner {
        if (_value == true) {
            burnableAccounts[_address] = _value;
            emit GrantACLto(msg.sender, _address, block.timestamp);
        } else {
            burnableAccounts[_address] = _value;
            emit RemoveACLfrom(msg.sender, _address, block.timestamp);
        }
    }

    // Athlete
    function setAthlete(address _address, bool _value) public onlyOwner{
        if (_value == true) {
            isAthlete[_address] = _value;
            emit AtheleteSet(msg.sender, _address, block.timestamp);
        } else {
            isAthlete[_address] = _value;
            emit RemovedAthelete(msg.sender, _address, block.timestamp);
        }
    }

    //pausable
    function accessPause(address _address, bool _value) public onlyOwner {
        if (_value == true) {
            pausableAccounts[_address] = _value;
            emit GrantACLto(msg.sender, _address, block.timestamp);
        } else {
            pausableAccounts[_address] = _value;
            emit RemoveACLfrom(msg.sender, _address, block.timestamp);
        }
    }

    //transferable
    function accessTransfer(address _address, bool _value) public onlyOwner {
        if (_value == true) {
            transferableAccounts[_address] = _value;
            emit GrantACLto(msg.sender, _address, block.timestamp);
        } else {
            transferableAccounts[_address] = _value;
            emit RemoveACLfrom(msg.sender, _address, block.timestamp);
        }
    }

    function athleteMintStatus(address _address, bool _value) external returns(bool){
        require(msg.sender == _ylOwner || msg.sender == nftAddress, "Not allowed");

        athleteMinted[_address] = _value;
        return(true);        
    }

    function isMintableAccount(address _address) external view returns (bool) {
        if (
            stakedAmount[_address][address(ylt)] >= sufficientstakeamount &&
            mintableAccounts[_address] == true
        ) {
            return true;
        } else {
            return false;
        }
    }

    function isBurnAccount(address _address) external view returns (bool) {
        if (
            stakedAmount[_address][address(ylt)] >= sufficientstakeamount &&
            burnableAccounts[_address] == true
        ) {
            return true;
        } else {
            return false;
        }
    }

    function isTransferAccount(address _address) external view returns (bool) {
        if (
            stakedAmount[_address][address(ylt)] >= sufficientstakeamount &&
            transferableAccounts[_address] == true
        ) {
            return true;
        } else {
            return false;
        }
    }

    function isPauseAccount(address _address) external view returns (bool) {
        if (
            stakedAmount[_address][address(ylt)] >= sufficientstakeamount &&
            pausableAccounts[_address] == true
        ) {
            return true;
        } else {
            return false;
        }
    }

    function isAthleteAccount(address _address) external view returns (bool) {
        if (
            stakedAmount[_address][address(ylt)] >= sufficientstakeamount &&
            isAthlete[_address] == true
        ) {
            return true;
        } else {
            return false;
        }
    }
    
    function athleteMintCheck(address _address) external view returns (bool) {
        return athleteMinted[_address];
    }

    function totalStakedAmount(address _user, address _contract) external view returns(uint){
        return stakedAmount[_user][_contract];
    }

    function getNFTMarket1Addr() public view returns (address){
        return marketNFTAddress1;
    }

    function getNFTMarket2Addr() public view returns (address){
        return marketNFTAddress2;
    }

    function getYLVaultAddr() public view returns(address) {
        return ylVault;
    }

    function getAuctionAddr() public view returns(address) {
        return auctionAddress;
    }

    function getMarketERC1155Addr() public view returns(address) {
        return marketERC1155Address;
    }
}
