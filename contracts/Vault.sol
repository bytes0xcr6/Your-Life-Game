//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLVault.sol";

contract Vault {

    IERC721 private ylNFTERC721;
    IERC1155 private ylNFTERC1155;
    IERC20 private ylERC20;

    address private treasuryAddress;

    event RevertTransferNftFromVaultToWalletERC721(address VaultAddress, address GamerAddress, uint256 NFTID, uint256 FeeAmount, uint256 RevertedTime);
    event RevertTransferNftFromVaultToWalletERC1155(address VaultAddress, address GamerAddress, uint256 NFTID, uint256 Amount, uint256 FeeAmount, uint256 RevertedTime);
    // Event to track when burned, id burned, player, and vaultAddress.
    event BoosterBurned(address VaultAddress, address GamerAddress, uint256 BoosterID, uint256 Amount, uint256 BurnedTime);

    constructor(IERC721 _ylNFTERC721, IERC1155 _ylNFTERC1155, IERC20 _ylERC20, address _treasuryAddress) {
        ylNFTERC721 = _ylNFTERC721;
        ylNFTERC1155 = _ylNFTERC1155;
        ylERC20 = _ylERC20;
        treasuryAddress = _treasuryAddress;
    }

    function revertNftFromVaultToWalletERC721(uint256[] memory _tokenIds, uint8 _category, uint256 _feePerNFT) external {
        require(_tokenIds.length > 0, "It mustn't 0");
        uint256 _fee = _feePerNFT * _tokenIds.length;
        require(ylERC20.balanceOf(msg.sender) >= _fee, "Insufficient balance for fee");
        //Update counter for each Sport.
        YLVault(treasuryAddress).updateCounter(msg.sender, _category, _tokenIds.length); 
        ylERC20.transferFrom(msg.sender, treasuryAddress, _fee);

        for(uint i=0; i < _tokenIds.length; i++) {
            ylNFTERC721.transferFrom(address(this), msg.sender, _tokenIds[i]); 
            emit RevertTransferNftFromVaultToWalletERC721(address(this), msg.sender, _tokenIds[i], _feePerNFT, block.timestamp);
        }
    }

    function revertNftFromVaultToWalletERC1155(uint256 _tokenId, uint8 _category, uint256 _amount, uint256 _feePerNFT) external {
        require(_amount > 0, "It mustn't 0");
        uint256 _fee = _feePerNFT * _amount;
        require(ylERC20.balanceOf(msg.sender) >= _fee, "Insufficient balance for fee");
        //Update counter for each Sport.
        YLVault(treasuryAddress).updateCounter(msg.sender, _category, _amount);
        ylERC20.transferFrom(address(this), msg.sender, _fee);

        ylNFTERC1155.safeTransferFrom(address(this), msg.sender, _tokenId, _amount, "");
        emit RevertTransferNftFromVaultToWalletERC1155(address(this), msg.sender, _tokenId, _amount, _fee, block.timestamp);
    }

    // Function to burn Boosters. ERC-1155?
    function burnBooster(uint _tokenId, uint _amount) public {
        ylNFTERC1155.safeTransferFrom(address(this), address(0), _tokenId, _amount, "");
        emit BoosterBurned(address(this), msg.sender, _tokenId, _amount, block.timestamp);
    }
}