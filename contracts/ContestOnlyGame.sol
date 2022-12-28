//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLVault.sol";
import "./YLProxy.sol";

contract ContestOnlyGame {
    IERC721 private ylNFTERC721;
    IERC1155 private ylNFTERC1155;
    IERC20 private ylERC20;
    YLProxy private ylProxy;
    YLVault private vaultAddress;
    address private treasuryAddress;
    uint private tokensNeededPlay;
    // uint8 private dailyMatchs;

    /// @dev Match struct to store the match info
    struct Match {
        uint8 category; /// @param SportCategory 1- Footbal, 2- Bastket, etc
        address[2] players; /// @param players address array representing players in this battle
        address winner; /// @param winner winner address
    }
    
    // Index for the won, draw and lost matchs per address. 1- Won matchs, 2- Lost matchs, 3- Draws
    mapping(address => mapping(uint8 => uint)) resultsPlayer; 
    // SportCategory => MatchCounter => MatchInfo
    mapping(uint8 => mapping(uint => Match)) matchIndex;
    // SportCategory => MatchCounter
    mapping(uint8 => uint) matchCounter;
    // TournamentID => player =>  Tournament FeePaid
    mapping(uint => mapping(address => bool)) feePaid;
    // Tournament ID => tournament Fee
    mapping(uint => uint) tournamentFee;
    // // Track tournament is not filled to access
    // mapping() playerTournament;

    event MatchFinished(address Winner, uint8 Category, address Looser, uint MatchID, uint SettedTime);
    event TournamentCommissionSetted(uint SettedFee, uint SettedTime);
    event TournamentFeePaid(address Player, uint TournamentID, uint SettedTime);
    event MinTokensStakedPlayUpdated(uint MinYLTStaked, uint SettedTime);

    modifier onlyOwner() {
        ylProxy.owner() == msg.sender;
        _;
    }

    constructor(IERC721 _ylNFTERC721, IERC1155 _ylNFTERC1155, IERC20 _ylERC20, YLProxy _ylProxy, YLVault _vaultAddress) {
        ylNFTERC721 = _ylNFTERC721;
        ylNFTERC1155 = _ylNFTERC1155;
        ylERC20 = _ylERC20;
        ylProxy = _ylProxy;
        vaultAddress = _vaultAddress;
    }

    // Play function, If we leave the _tournament parameter as 0 it will take it as a daily game. 
    function play(address _player1, uint _score1, address _player2, uint _score2, uint8 _category, uint8 _tournamentID) external onlyOwner{
        require(ylProxy.totalStakedAmount(_player1, address(ylERC20)) >= tokensNeededPlay, "You need to stake more YLT");
        require(ylProxy.totalStakedAmount(_player2, address(ylERC20)) >= tokensNeededPlay, "You need to stake more YLT");
        require(YLVault(vaultAddress).checkElegible(_player1, _category) == true, "You are not elegible.");
        require(YLVault(vaultAddress).checkElegible(_player2, _category) == true, "You are not elegible.");

        // If we add the tournament ID, it will check if they paid for the tournament feee
        if(_tournamentID > 0) {
            require(feePaid[_tournamentID][_player1], "Player 1 did not pay the tournament fee.");
            require(feePaid[_tournamentID][_player2], "Player 2 did not pay the tournament fee.");
        }
        
        address winner;
        address looser;
        uint _randomCoheficient1; //= getRandomNum();
        uint _randomCoheficient2; //= getRandomNum();

        if((_score1 + _randomCoheficient1) > (_score2 + _randomCoheficient2)) {
            winner = _player1;
            looser = _player2;
            resultsPlayer[winner][1]++; //Increment wins
            resultsPlayer[looser][2]++; // Increment looses

        }else if((_score1 + _randomCoheficient1) < (_score2 + _randomCoheficient2)) {
            winner = _player2;
            looser = _player1;
            resultsPlayer[winner][1]++; //Increment wins
            resultsPlayer[looser][2]++; // Increment looses
        } else {
            winner = address(0); // Draw
            looser = address(0); 
            resultsPlayer[winner][3]++; //Increment wins
            resultsPlayer[looser][3]++; // Increment looses
        }

        Match memory _match = Match (
            _category,
            [msg.sender, address(0)],
            address(winner)
        );
        matchIndex[_category][matchCounter[_category]] = _match;

        emit MatchFinished(winner, _category, looser, matchCounter[_category], block.timestamp);
        matchCounter[_category]++;
    }

    // //CHAINLINK. Generates 2 randomNumbers to increment each of the players final score. CHAINLINK
    // function getRandomNum() {

    // }

    // Pay YLT fee to be elegible for a tournament, passing the tournament ID.
    function payTournamentFee(uint8 _tournamentID) external {
        require(!feePaid[_tournamentID][msg.sender], "You have already paid the fee");
        ylERC20.transferFrom(msg.sender, treasuryAddress, tournamentFee[_tournamentID]);
        feePaid[_tournamentID][msg.sender] = true;
        emit TournamentFeePaid(msg.sender, _tournamentID, block.timestamp);
    }

    function withdrawFunds(address payable _to, uint _amount) external onlyOwner{
        payable(_to).transfer(_amount);
    }

    function setTournamentFee(uint _tournamentID, uint _fee) external onlyOwner{
        tournamentFee[_tournamentID] = _fee;
        emit TournamentCommissionSetted(_fee, block.timestamp);
    }

    // Setter for the minimum a player needs to stake to play
    function setMinStakedPlay(uint _amount) external onlyOwner{
        tokensNeededPlay = _amount;
        emit MinTokensStakedPlayUpdated(_amount, block.timestamp);
    }

    // Getter if the player is elegible to play based on the YLT staked.
    function isElegible(address _player) public view returns(bool) {
        require(ylProxy.totalStakedAmount(_player, address(ylERC20)) >= tokensNeededPlay, "You need to stake more YLT");
        return true;
    }

    // Getter for the minimum staked YLT staked.
    function getMinStakedPlay() public view returns(uint){
        return tokensNeededPlay;
    }

    // Getter for TournamentFee to access the tournament.
    function getTournamentFee(uint _tournamentID) external view returns(uint){
        return tournamentFee[_tournamentID];
    }

    // Getter for Match details.
    function getMatch(uint8 _category, uint _matchId) public view returns(Match memory){
        return matchIndex[_category][_matchId];
    }

    // Getter for total wins, draw and looses by player. 1- Wins, 2- Looses, 3- Draws.
    function getPlayerRecord(address _player, uint8 _decision) public view returns(uint){
        return resultsPlayer[_player][_decision];
    }
}


/*  *YLVAULT CONTRACT: 
        Substorage Fabric to create and asociate subvaults to wallets, where the users can deposit their ERC721(NFTs) & ERC1155(Boosters)
    
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


    *VAULT CONTRACT:
        Substorage for keeping user´s ERC721(NFTs) & ERC1155(Boosters).
    
    - Players / Partners can withdraw/revert their ERC721(NFTs) & ERC1155(Boosters) at any time, but they have to pay a fee.
    - Burning option for Boosters.

     EVENTS:
        event RevertTransferNftFromVaultToWalletERC721(address VaultAddress, address GamerAddress, uint256 NFTID, uint256 FeeAmount, uint256 RevertedTime);
        event RevertTransferNftFromVaultToWalletERC1155(address VaultAddress, address GamerAddress, uint256 NFTID, uint256 Amount, uint256 FeeAmount, uint256 RevertedTime);
        event BoosterBurned(address VaultAddress, address GamerAddress, uint256 BoosterID, uint256 Amount, uint256 BurnedTime);
        event feePerNFTUpdated(uint NewFee, uint UpdatedTime);


    *CONTEST CONTRACT:
        This contract tracks the game results and offerts the game logic, user can pay tournament fees and check if the player paid for the tournament fees.
    
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
*/
