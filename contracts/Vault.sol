//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";   
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLVault.sol";
import "./YLNFT.sol";

interface IBurner {
    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) external ;
}

contract Vault is IERC1155Receiver {

    IERC721 public ylNFTERC721;
    IERC1155 public ylNFTERC1155;
    IERC20 public ylERC20;
    YLNFT public ylNFT;
    IBurner private burnerERC1155;
    YLVault public vaultFactory;

    event RevertedERC721(address vaultAddr, address gamerAddr, uint256 nFTID, uint256 fee, uint256 revertTime);
    event RevertedERC1155(address vaultAddr, address gamerAddr, uint256 nFTID, uint256 amount, uint256 fee, uint256 revertTime);
    event BoostersBurned(address vaultAddr, address gamerAddr, uint256[] boosterID, uint256[] Amount, uint256 burnTime);

    constructor(address _ylNFTERC721, address _ylNFTERC1155, address _ylERC20) {
        ylNFTERC721 = IERC721(_ylNFTERC721);
        ylNFTERC1155 = IERC1155(_ylNFTERC1155);
        ylERC20 = IERC20(_ylERC20);
        ylNFT = YLNFT(_ylNFTERC721);
        burnerERC1155 = IBurner(_ylNFTERC1155);
        vaultFactory = YLVault(msg.sender);
    }

    // Function to transfer ERC721 (NFT) from Personal Vault to Wallet.
    function revertNftFromVaultToWalletERC721(uint256[] memory _tokenIds) external {
        require(YLVault(vaultFactory).vaultContract(msg.sender) == address(this), "You`r not the subVault owner");
        require(_tokenIds.length > 0, "It mustn't 0");
        //Get fees from the YLVault contract and multiply for the tokens length.
        uint256 _fee = YLVault(vaultFactory).revertNFTComision() * _tokenIds.length;
        require(ylERC20.balanceOf(msg.sender) >= _fee, "Insufficient balance for fee");
        ylERC20.transferFrom(msg.sender, vaultFactory.treasuryAddress(), _fee);

        for(uint i=0; i < _tokenIds.length; i++) {
            string memory _category = ylNFT.getCategory(_tokenIds[i]);
            ylNFTERC721.transferFrom(address(this), msg.sender, _tokenIds[i]); 
            YLVault(vaultFactory).updateCounter(msg.sender, _category, _tokenIds.length); 
            emit RevertedERC721(address(this), msg.sender, _tokenIds[i], _fee, block.timestamp);
        }
    }

    // Function to transfer ERC1155 (Boosters) from Personal Vault to Wallet.
    function revertNftFromVaultToWalletERC1155(uint256 _tokenId, string memory _category, uint256 _amount) external {
        require(_amount > 0, "It mustn't 0");
        require(YLVault(vaultFactory).vaultContract(msg.sender) == address(this), "You`r not the subVault owner");
        //Get fees from the YLVault contract and multiply for the tokens length.
        uint256 _fee = YLVault(vaultFactory).revertNFTComision() * _amount;
        require(ylERC20.balanceOf(msg.sender) >= _fee, "Insufficient balance for fee");
        //Update counter for each Sport.
        YLVault(vaultFactory).updateCounter(msg.sender, _category, _amount);
        ylERC20.transferFrom(msg.sender, vaultFactory.owner(), _fee);

        ylNFTERC1155.safeTransferFrom(address(this), msg.sender, _tokenId, _amount, "");
        emit RevertedERC1155(address(this), msg.sender, _tokenId, _amount, _fee, block.timestamp);
    }

    // Function to burn Boosters.
    function burnBoosters(uint[] memory _tokenId, uint[] memory _amount) external {
        burnerERC1155.burnBatch(address(this), _tokenId, _amount);
        
        emit BoostersBurned(address(this), msg.sender, _tokenId, _amount, block.timestamp);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(ylNFTERC1155), "received from unauthenticated contract");
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(ylNFTERC1155), "received from unauthenticated contract");
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
    return true;
    }
}
