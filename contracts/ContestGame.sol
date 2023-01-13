//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLVault.sol";
import "./YLProxy.sol";

contract ContestGame {
    IERC721 public ylNFTERC721;
    IERC1155 public ylNFTERC1155;
    IERC20 public ylERC20;
    YLProxy public ylProxy;
    YLVault public vaultAddress;
    uint public tokensNeededPlay;
    uint private tournamentCount;
    uint private matchCount;

    /// @dev Match struct to store the match info
    struct Match {
        string category; /// @param SportCategory
        address[2] players; /// @param players address array representing players in this battle
        address winner; /// @param winner winner address
    }

    struct Tournament {
        uint tournamentID;
        string category;
        address[] players;
        uint maxPlayers;
        uint tournamentFee;
        uint totalPaidFees;
    }
    
    // Index for the won, draw and lost matchs per address. 1- Won matchs, 2- Lost matchs, 3- Draws
    mapping(address => mapping(uint8 => uint)) private resultsPlayer; 
    // TournamentID => player =>  Tournament FeePaid
    mapping(uint => mapping(address => bool)) public feePaid;
    // TournamentID => tournament Info
    mapping(uint => Tournament) public tournamentIndex;
    // MatchID => Match Info
    mapping(uint => Match) public matchIndex;
    /*  Round 0 => User did not participate. (It is incremented when tournament Fee is paid)
        Round 1 => Player lost on the first round or he did not play yet firs round.
        Round 2 => Player lost on the second round or he did not play yet second round.
    TournamentID => player address => round; */
    mapping(uint => mapping(address => uint)) private roundReached;
    // Tournament ID => tournamentRound => player => bool
    mapping(uint => mapping(uint => mapping(address =>bool))) private hasPlayed;


    event MatchCreated(address player1, address player2, string category, uint matchID, uint creationTime);
    event MatchFinished(address winner, string category, address looser, uint matchID, uint tournamentID, uint settedTime);
    event tournamentMatchFinished(address winner, string category, address looser, uint matchID, uint tournamentID, uint settedTime);
    event TournamentCommissionSetted(uint settedFee, uint settedTime);
    event TournamentCreated(string category, uint tournamentID, uint maxPlayers, uint tournamentFee, uint creationTime);
    event TournamentFeePaid(address player, uint tournamentID, uint settedTime);
    event MinTokensStakedPlayUpdated(uint minYLTStaked, uint settedTime);

    modifier onlyOwner() {
        ylProxy.owner() == msg.sender;
        _;
    }

    constructor(IERC721 _ylNFTERC721, IERC1155 _ylNFTERC1155, IERC20 _ylERC20, YLProxy _ylProxy, YLVault _vault) {
        ylNFTERC721 = _ylNFTERC721;
        ylNFTERC1155 = _ylNFTERC1155;
        ylERC20 = _ylERC20;
        ylProxy = _ylProxy;
        vaultAddress = _vault;
    }

    function createMatchID(address _player1, address _player2, string memory _category) public onlyOwner{

        Match memory _match = Match (
            _category,
            [_player1, _player2],
            address(0)
        );

        matchIndex[matchCount] = _match;


        emit MatchCreated(_player1, _player2, _category, matchCount, block.timestamp);
        matchCount++;
    }

    // Play function, If we leave the _tournament parameter as 0 it will take it as a daily game. 
    function play(address _player1, uint _score1, address _player2, uint _score2, uint _matchID, string memory _category, uint8 _tournamentID) external onlyOwner{
        require(ylProxy.totalStakedAmount(_player1, address(ylERC20)) >= tokensNeededPlay, "Stake more YLT");
        require(ylProxy.totalStakedAmount(_player2, address(ylERC20)) >= tokensNeededPlay, "Stake more YLT");
        require(YLVault(vaultAddress).checkElegible(_player1, _category) == true, "You are not elegible.");
        require(YLVault(vaultAddress).checkElegible(_player2, _category) == true, "You are not elegible.");
        require(matchIndex[_matchID].players.length == 2, "MatchID Empty");
        require(matchIndex[_matchID].players[0] == _player1, "Wrong player1");
        require(matchIndex[_matchID].players[1] == _player2, "Wrong player2");


        // If we add the tournament ID, it will check if they paid for the tournament fee. 
        // The first tournament ID must be 1.
        if(_tournamentID > 0) {
            require(feePaid[_tournamentID][_player1], "Play1 did`nt pay tournamentFee.");
            require(feePaid[_tournamentID][_player2], "Play2 did`nt pay tournamentFee.");
        }
        
        address winner;
        address looser;
        uint _randomCoheficient1 = random(_player1);
        uint _randomCoheficient2 = random(_player2);

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
            resultsPlayer[winner][3]++; //Increment draws
            resultsPlayer[looser][3]++; // Increment draws
        }

        matchIndex[_matchID].winner = winner;
        // Increment the round, so the looser will stay in the previous round and 
        // the winner will pass to the next round.
        // - Mark as true the looser.
        if(_tournamentID > 0) {
            roundReached[_tournamentID][winner]++;
            hasPlayed[_tournamentID][roundReached[_tournamentID][looser]][looser] = true;
            emit tournamentMatchFinished (winner, _category, looser, _matchID, _tournamentID, block.timestamp);
        }


        if(_tournamentID == 0 ){
        emit MatchFinished(winner, _category, looser, _matchID, _tournamentID, block.timestamp);
        }
    }

    // Generates a random number from 1 to 9
    function random(address _player) internal view returns (uint) {
    uint randomnumber = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, _player))) % 9;
    randomnumber++;
    return randomnumber;
    }

    function createTournament(string memory _category, uint _maxPlayers, uint _tournamentFee ) external onlyOwner {
        // require("Que sean pares");
        Tournament memory newTournament;

        newTournament.tournamentID = tournamentCount;
        newTournament.category = _category;
        newTournament.maxPlayers = _maxPlayers; 
        newTournament.tournamentFee = _tournamentFee;

        tournamentIndex[tournamentCount] = newTournament;

        emit TournamentCreated(_category, tournamentCount, _maxPlayers, _tournamentFee, block.timestamp);
        tournamentCount++;
    }

    // Pay YLT fee to be elegible for a tournament, passing the tournament ID.
    function payTournamentFee(uint8 _tournamentID) external {
        require(!feePaid[_tournamentID][msg.sender], "You have already paid the fee");
        require(tournamentIndex[_tournamentID].players.length <= tournamentIndex[_tournamentID].maxPlayers, "Tournament is full");
        uint fee = tournamentIndex[_tournamentID].tournamentFee;
        ylERC20.transferFrom(msg.sender, ylProxy.owner(), fee);
        feePaid[_tournamentID][msg.sender] = true;
        tournamentIndex[_tournamentID].players.push(msg.sender);
        tournamentIndex[_tournamentID].totalPaidFees += fee;
        roundReached[_tournamentID][msg.sender] = 1;
        emit TournamentFeePaid(msg.sender, _tournamentID, block.timestamp);
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

    // Getter for TournamentFee to access the tournament.
    function getTournamentFee(uint _tournamentID) external view returns(uint){
        return tournamentIndex[_tournamentID].tournamentFee;
    }

    // Getter for Match details.
    function getMatch(uint _matchId) public view returns(Match memory){
        return matchIndex[_matchId];
    }

    // Getter for total wins, draw and looses by player. 1- Wins, 2- Looses, 3- Draws.
    function getPlayerRecord(address _player, uint8 _decision) public view returns(uint){
        return resultsPlayer[_player][_decision];
    }

    /* 
        1. Check the round where the player is at the moment in the tournament.
        2. Check if the player has played. 
            If true, it means the player has lost in this round.
            If false, it means the player has NOT lost and he has to play the next round.
    */

    // 1. Getter for the round of a player in a specific tournament.
    function getRound(uint _tournamentID, address _player) public view returns(uint){
        return roundReached[_tournamentID][_player];
    }

    // 2. Getter for the player match status in tournament.
    function roundPlayed(uint _tournamentID, uint _round, address _player) public view returns(bool){
        return hasPlayed[_tournamentID][_round][_player];
    }

    function getTournament(uint _tournamentID) public view returns(Tournament memory){
        return tournamentIndex[_tournamentID];
    }
}
