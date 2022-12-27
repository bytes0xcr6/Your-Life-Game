//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Vault.sol";


contract YLVault is Ownable{
    IERC721 private ylNFTERC721;
    IERC1155 private ylNFTERC1155;
    IERC20 private ylERC20;
    address private treasuryAddress;

    mapping(address => address) public vaultContract;
    // address => SportCategory => amountNFTs Total amount of NFTs in substorage per address and Sport.  1- Footbal, 2- Basketball, 3- Rugby (Example)
    mapping(address => mapping (uint8 => uint)) public NFTsCounter; 
    // // SportCategory => Number of players ready to play. 
    // mapping(uint8 => uint) public playersElegibles;
    //address => SportCategory => elegible. Gamer is elegible to play, as he added at least 5 footbal players (Example)
    mapping(address => mapping (uint8 => bool)) public elegibleGamer; 
    // SportCategory => playersNeeded. Example: Footbal: 11;
    mapping(uint8 => uint8) public playersNeeded;

    event RevertNftToWalletCommissionSetted(uint256 SettedFee, uint256 SettedTime);
    event DepositedNftFromWalletToVaultERC721(address FromAddress, address GamerAddress, address VaultAddress, uint256 TokenId, uint256 DepositedTime);
    event DepositedNftFromWalletToVaultERC1155(address FromAddress, address GamerAddress, address VaultAddress, uint256 TokenId, uint256 Amount, uint256 DepositedTime);

    constructor(IERC721 _ylNFTERC721, IERC1155 _ylNFTERC1155, IERC20 _ylERC20) {
        ylNFTERC721 = _ylNFTERC721;
        ylNFTERC1155 = _ylNFTERC1155;
        ylERC20 = _ylERC20;
        treasuryAddress = owner();
    }

    function storeNftFromWalletToVaultERC721(address gamerAddress, uint8 _category, uint256[] memory _tokenIds) external {
        require(_tokenIds.length > 0, "It mustn't 0");

        if(vaultContract[gamerAddress] == address(0x0)) {
            Vault newVault = new Vault(ylNFTERC721, ylNFTERC1155, ylERC20, treasuryAddress);
            vaultContract[gamerAddress] = address(newVault);
        }
        for(uint i = 0; i < _tokenIds.length; i++)
        {
            ylNFTERC721.transferFrom(msg.sender, vaultContract[gamerAddress], _tokenIds[i]);
            NFTsCounter[gamerAddress][_category] += _tokenIds.length; //Update counter for each Sport.
            emit DepositedNftFromWalletToVaultERC721(msg.sender, gamerAddress, vaultContract[gamerAddress], _tokenIds[i], block.timestamp);
        }

        // Update elegibility
        if(NFTsCounter[gamerAddress][_category] > playersNeeded[_category]) {
            elegibleGamer[gamerAddress][_category] = true;
        }
    }

    function storeNftFromWalletToVaultERC1155(address gamerAddress, uint8 _category, uint256 _tokenId, uint256 _amount) external {
        require(_amount > 0, "It mustn't 0");
    
        if(vaultContract[gamerAddress] == address(0x0)) {
            Vault newVault = new Vault(ylNFTERC721, ylNFTERC1155, ylERC20, treasuryAddress);
            vaultContract[gamerAddress] = address(newVault);
        }
        
        ylNFTERC1155.safeTransferFrom(msg.sender, vaultContract[gamerAddress], _tokenId, _amount, "");
        NFTsCounter[gamerAddress][_category] += _amount; //Update counter for each Sport.

        // Update elegibility
        if(NFTsCounter[gamerAddress][_category] > playersNeeded[_category]) {
            elegibleGamer[gamerAddress][_category] = true;
        }

        emit DepositedNftFromWalletToVaultERC1155(msg.sender, gamerAddress, vaultContract[gamerAddress], _tokenId, _amount, block.timestamp);
    }

    function setRevertNftToWalletCommision(uint256 _fee) external onlyOwner returns(uint256){
        emit RevertNftToWalletCommissionSetted(_fee, block.timestamp);
        return _fee;
    }

    // Setter from the Vault substorage Counter. 
    function updateCounter(address _gamer, uint8 _category, uint _amount) external {
        require(vaultContract[_gamer] != msg.sender, "You are not the vault owner");
        NFTsCounter[_gamer][_category] -= _amount; 
        
        if(NFTsCounter[_gamer][_category] < playersNeeded[_category]) {
            elegibleGamer[_gamer][_category] = false;
        }
    }

    // Setter for the minimum number of players per category.
    function addNewSport(uint8 _category, uint8 _playersNeeded) external onlyOwner{
        playersNeeded[_category] = _playersNeeded;
    }

    function checkElegible(address _user, uint8 _category) public view returns(bool){
        return elegibleGamer[_user][_category];
    }

}
