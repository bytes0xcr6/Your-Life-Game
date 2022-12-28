# Your-Life-Game
P2E Sport Game

# YLVAULT CONTRACT: 

**Substorage Fabric to create and asociate subvaults to wallets, where the users can deposit their ERC721(NFTs) & ERC1155(Boosters)**
    
    - Deposit function for storing ERC-721 in the subVault & and creating a new subvault if they user did not create one before.
    - Deposit function for storing ERC-1155 in the subVault & and creating a new subvault if they user did not create one before.
    - Setter for NFTWithdraw fee.
    - Setter for adding a new Sport and the players needed.
    - Setter for updating the amount of NFTs of each user has per Sport Category. HOW DO WE MAKE SURE THE USER IS NOT CHOOSING THE WRONG CATEGORY?
    - Getter for the subvault of the wallet address passed.
    - Getter for checking if the user is elegible for an specific category.
    - Getter for the NFTWithdraw fee.
     EVENTS: 
     - event RevertNftToWalletCommissionSetted(uint256 SettedFee, uint256 SettedTime);
     - event DepositedNftFromWalletToVaultERC721(address FromAddress, address GamerAddress, address VaultAddress, uint256 TokenId, uint256 DepositedTime);
     - event DepositedNftFromWalletToVaultERC1155(address FromAddress, address GamerAddress, address VaultAddress, uint256 TokenId, uint256 Amount, uint256 DepositedTime);


# VAULT CONTRACT:
**Substorage for keeping user´s ERC721(NFTs) & ERC1155(Boosters).**
    
    - Players / Partners can withdraw/revert their ERC721(NFTs) & ERC1155(Boosters) at any time, but they have to pay a fee.
    - Burning option for Boosters.

     EVENTS:
        event RevertTransferNftFromVaultToWalletERC721(address VaultAddress, address GamerAddress, uint256 NFTID, uint256 FeeAmount, uint256 RevertedTime);
        event RevertTransferNftFromVaultToWalletERC1155(address VaultAddress, address GamerAddress, uint256 NFTID, uint256 Amount, uint256 FeeAmount, uint256 RevertedTime);
        event BoosterBurned(address VaultAddress, address GamerAddress, uint256 BoosterID, uint256 Amount, uint256 BurnedTime);
        event feePerNFTUpdated(uint NewFee, uint UpdatedTime);


# CONTEST CONTRACT:
**This contract tracks the game results and offerts the game logic, user can pay tournament fees and check if the player paid for the tournament fees.**
    
    - Function to play (ONLY OWNER). Requires the next parameters: players Address, each players final score, CategoryID, TournamentID (if needed). It will generate 2 random number to add to each player´s final score.
    - Funtion to pay the tournament fee in YLT. (It will set the msg.sender as elegible for the tournament selected)    
    - Function to WITHDRAW the funds in the contract (ONLY OWNER).
    - Setter for the tournament fee.
    - Setter for the minimum YLT staked to play.
    - Getter for checking if the address is elegible to play (Based on the YLT tokens staked). Useful for checking elegibility before matching players.
    - Getter for the minimum to stake to be elegible to play.
    - Getter for the tournament fee. (Requires the Tournament ID)
    - Getter for the Match details. (Requires the Category & Match ID)
    - Getter for the player record of victories, looses, drawns. (Requires user wallet)

     EVENTS:
        event MatchFinished(address Winner, uint8 Category, address Looser, uint MatchID, uint SettedTime);
        event TournamentCommissionSetted(uint SettedFee, uint SettedTime); 
        event TournamentFeePaid(address Player, uint TournamentID, uint SettedTime);
        event MinTokensStakedPlayUpdated(uint MinYLTStaked, uint SettedTime);
        
        
 # EXTRA ADDED TO OTHER CONTRACTS
 
 **YLproxy.sol**
 
 Getter for the total YLT staked by address & contract.
 ```
 function totalStakedAmount(address _user, address _contract) external view returns(uint){
        return stakedAmount[_user][_contract];
    }
```
 
