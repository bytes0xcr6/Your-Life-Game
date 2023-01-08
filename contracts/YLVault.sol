//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLNFT.sol";
import "./Vault.sol";

contract YLVault is Ownable{
    IERC721 public ylNFTERC721;
    IERC1155 public ylNFTERC1155;
    IERC20 public ylERC20;
    address public treasuryAddress;
    uint public revertNFTComision;

    // player address => subStorageVault address
    mapping(address => address) public vaultContract;
    // player address => SportCategory => amountNFTs Total amount of NFTs in substorage per address and Sport.  1- Footbal, 2- Basketball, 3- Rugby (Example)
    mapping(address => mapping (string => uint)) public NFTsCounter; 
    // player address => SportCategory => elegible. Gamer is elegible to play, as he added at least 5 footbal players (Example)
    mapping(address => mapping (string => bool)) public elegibleGamer; 
    // SportCategory => playersNeeded. Example: Footbal: 11;
    mapping(string => uint8) public playersNeeded;

    event RevertNftToWalletCommissionSetted(uint256 SettedFee, uint256 SettedTime);
    event DepositedERC721(address From, address Gamer, address Vault, uint256 TokenId, uint256 DepositTime);
    event DepositedERC1155(address From, address Gamer, address Vault, uint256 TokenId, uint256 Amount, uint256 DepositTime);

    constructor(IERC721 _ylNFTERC721, IERC1155 _ylNFTERC1155, IERC20 _ylERC20) {
        ylNFTERC721 = _ylNFTERC721;
        ylNFTERC1155 = _ylNFTERC1155;
        ylERC20 = _ylERC20;
        treasuryAddress = owner();
    }

    // Transfers ERC721 (NFT) from Wallet to Personal Vault.
    function storeNftFromWalletToVaultERC721(address _gamer, uint256[] memory _tokenIds) external {
        require(_tokenIds.length > 0, "It mustn't 0");
        if(vaultContract[_gamer] == address(0x0)) {
            Vault newVault = new Vault(address(ylNFTERC721), address(ylNFTERC1155), address(ylERC20));
            vaultContract[_gamer] = address(newVault);
        }
        for(uint i = 0; i < _tokenIds.length; i++)
        {
            require(ylNFTERC721.ownerOf(_tokenIds[i]) == msg.sender, "You do not own this NFTs");

            string memory _category = YLNFT(address(ylNFTERC721)).getCategory(_tokenIds[i]);
            ylNFTERC721.transferFrom(msg.sender, vaultContract[_gamer], _tokenIds[i]);
            NFTsCounter[_gamer][_category] += 1; //Update counter for each Sport.
        // Update elegibility
            if(NFTsCounter[_gamer][_category] > playersNeeded[_category]) {
                elegibleGamer[_gamer][_category] = true;
            }
            emit DepositedERC721(msg.sender, _gamer, vaultContract[_gamer], _tokenIds[i], block.timestamp);
        }

    }

    // Transfers ERC1155 (Boosters) from Wallet to Personal Vault.
    function storeNftFromWalletToVaultERC1155(address _gamer, uint256 _tokenId, uint256 _amount) external {
        require(_amount > 0, "It mustn't 0");
        require(ylNFTERC1155.balanceOf(msg.sender, _tokenId) <= _amount, "You need more Boosters");
    
        if(vaultContract[_gamer] == address(0x0)) {
            Vault newVault = new Vault((address(ylNFTERC721)), address(ylNFTERC1155), address(ylERC20));
            vaultContract[_gamer] = address(newVault);
        }
        
        ylNFTERC1155.safeTransferFrom(msg.sender, vaultContract[_gamer], _tokenId, _amount, "");

        emit DepositedERC1155(msg.sender, _gamer, vaultContract[_gamer], _tokenId, _amount, block.timestamp);
    }

    // Setter from the Vault substorage Counter when we revert NFTs to Wallet. 
    function updateCounter(address _gamer, string memory _category, uint _amount) external {
        require(vaultContract[_gamer] == msg.sender, "You are not the vault owner");
        NFTsCounter[_gamer][_category] -= _amount; 
        
        if(NFTsCounter[_gamer][_category] < playersNeeded[_category]) {
            elegibleGamer[_gamer][_category] = false;
        }  
    }

    // Setter for reverting NFTs from the subvault to the owner´s wallet
    function setRevertNftToWalletCommision(uint256 _fee) external onlyOwner{
        revertNFTComision = _fee;
        emit RevertNftToWalletCommissionSetted(_fee, block.timestamp);
    }

    // Setter for the minimum number of players per category.
    function addNewSport(string memory _category, uint8 _playersNeeded) external onlyOwner{
        playersNeeded[_category] = _playersNeeded;
    }

    // Getter for the subVault of wallet address
    function getSubvault(address _gamer) external view returns(address){
        return vaultContract[_gamer];
    }

    // Check if the wallet is elegible to play.
    function checkElegible(address _gamer, string calldata _category) external view returns(bool){
        return elegibleGamer[_gamer][_category];
    }
}
