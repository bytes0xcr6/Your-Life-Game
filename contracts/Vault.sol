//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLVault.sol";
import "./YLNFT.sol";

contract Vault {

    IERC721 public ylNFTERC721;
    IERC1155 public ylNFTERC1155;
    IERC20 public ylERC20;
    YLNFT public ylNFT;

    address public treasuryAddress;

    event RevertTransferNftFromVaultToWalletERC721(address VaultAddress, address GamerAddress, uint256 NFTID, uint256 FeeAmount, uint256 RevertedTime);
    event RevertTransferNftFromVaultToWalletERC1155(address VaultAddress, address GamerAddress, uint256 NFTID, uint256 Amount, uint256 FeeAmount, uint256 RevertedTime);
    event BoosterBurned(address VaultAddress, address GamerAddress, uint256 BoosterID, uint256 Amount, uint256 BurnedTime);
    event feePerNFTUpdated(uint NewFee, uint UpdatedTime);

    constructor(address _ylNFTERC721, IERC1155 _ylNFTERC1155, IERC20 _ylERC20, address _treasuryAddress) {
        ylNFTERC721 = IERC721(_ylNFTERC721);
        ylNFTERC1155 = _ylNFTERC1155;
        ylERC20 = _ylERC20;
        ylNFT = YLNFT(_ylNFTERC721);
        treasuryAddress = _treasuryAddress;
    }

    // Function to transfer ERC721 (NFT) from Personal Vault to Wallet.
    function revertNftFromVaultToWalletERC721(uint256[] memory _tokenIds) external {
        require(YLVault(treasuryAddress).vaultContract(msg.sender) == address(this), "You`r not the subVault owner");
        require(_tokenIds.length > 0, "It mustn't 0");
        //Get fees from the YLVault contract and multiply for the tokens length.
        uint256 _fee = YLVault(treasuryAddress).revertNFTComision() * _tokenIds.length;
        require(ylERC20.balanceOf(msg.sender) >= _fee, "Insufficient balance for fee");
        //Update counter for each Sport.
        ylERC20.transferFrom(msg.sender, treasuryAddress, _fee);

        for(uint i=0; i < _tokenIds.length; i++) {
            string memory _category = ylNFT.getCategory(_tokenIds[i]);
            ylNFTERC721.transferFrom(address(this), msg.sender, _tokenIds[i]); 
            YLVault(treasuryAddress).updateCounter(msg.sender, _category, _tokenIds.length); 
            emit RevertTransferNftFromVaultToWalletERC721(address(this), msg.sender, _tokenIds[i], _fee, block.timestamp);
        }
    }

    // Function to transfer ERC1155 (Boosters) from Personal Vault to Wallet.
    function revertNftFromVaultToWalletERC1155(uint256 _tokenId, string memory _category, uint256 _amount) external {
        require(_amount > 0, "It mustn't 0");
        require(YLVault(treasuryAddress).vaultContract(msg.sender) == address(this), "You`r not the subVault owner");
        //Get fees from the YLVault contract and multiply for the tokens length.
        uint256 _fee = YLVault(treasuryAddress).revertNFTComision() * _amount;
        require(ylERC20.balanceOf(msg.sender) >= _fee, "Insufficient balance for fee");
        //Update counter for each Sport.
        YLVault(treasuryAddress).updateCounter(msg.sender, _category, _amount);
        ylERC20.transferFrom(address(this), msg.sender, _fee);

        ylNFTERC1155.safeTransferFrom(address(this), msg.sender, _tokenId, _amount, "");
        emit RevertTransferNftFromVaultToWalletERC1155(address(this), msg.sender, _tokenId, _amount, _fee, block.timestamp);
    }

    // Function to burn Boosters.
    function burnBooster(uint _tokenId, uint _amount) external {
        ylNFTERC1155.safeTransferFrom(address(this), address(0), _tokenId, _amount, "");
        emit BoosterBurned(address(this), msg.sender, _tokenId, _amount, block.timestamp);
    }
}
