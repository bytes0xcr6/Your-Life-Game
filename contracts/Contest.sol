//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLVault.sol";
import "./YLProxy.sol";

contract Contest is Ownable {
    IERC721 private ylNFTERC721;
    IERC1155 private ylNFTERC1155;
    IERC20 private ylERC20;
    YLProxy private ylProxy;
    YLVault private vaultAddress;
    address private treasuryAddress;
    uint matchFee;
    uint8 dailyMatchs;

    enum MatchStatus{ PENDING, STARTED, ENDED }

    /// @dev Match struct to store the match info
    struct Match {
        MatchStatus matchStatus; /// @param matchStatus enum to indicate battle status
        uint8 category; /// @param SportCategory 1- Footbal, 2- Bastket, etc
        address[2] players; /// @param players address array representing players in this battle
        address winner; /// @param winner winner address
    }
    
    // Index for the won and lost matchs per address. 1- Won matchs, 2- Lost matchs.
    mapping(address => mapping(uint8 => uint)) resultsPlayer; 
    // SportCategory => MatchCounter => MatchInfo
    mapping(uint8 => mapping(uint => Match)) matchIndex;
    mapping(address => bool) playing;
    // SportCategory => MatchCounter
    mapping(uint8 => uint) matchCounter;

    event MatchCreated(address GameCreator, uint8 Category, uint MatchID, uint SettedTime);
    event RivalFound(address GameCreator, uint8 Category, address Rival, uint MatchID, uint SettedTime);
    event MatchFinished(address Winner, uint8 Category, address Looser, uint MatchID, uint SettedTime);
    event MatchCommissionSetted(uint SettedFee, uint SettedTime);
    event NewAdminSetted(address NewAdmin, uint SettedTime);
    event TotalDailyMatchsUpdated(uint8 DailyMatchs, uint SettedTime);


    constructor(IERC721 _ylNFTERC721, IERC1155 _ylNFTERC1155, IERC20 _ylERC20, YLProxy _ylProxy, YLVault _vaultAddress) {
        ylNFTERC721 = _ylNFTERC721;
        ylNFTERC1155 = _ylNFTERC1155;
        ylERC20 = _ylERC20;
        ylProxy = _ylProxy;
        vaultAddress = _vaultAddress;
        treasuryAddress = owner();
    }


    /// @dev Creates a new match.
    /// @param _category match; set by player
    function createMatch(uint8 _category) external payable returns(Match memory){
        require(msg.value == matchFee, "Pay the Match fee.");
        require(YLVault(vaultAddress).checkElegible(msg.sender, _category) == true, "You are not elegible.");
        require(!playing[msg.sender], "Finish your match before");
        playing[msg.sender] = true;
        Match memory _match = Match (
            MatchStatus.PENDING,
            _category,
            [msg.sender, address(0)],
            address(0)
        );
        matchIndex[_category][matchCounter[_category]] = _match;

        emit MatchCreated(msg.sender, _category, matchCounter[_category], block.timestamp);
        matchCounter[_category]++;
        return _match;
    }

  /// @dev Player joins match
  /// @param _category; category sport match player wants to join
    function joinMatch(uint8 _category) external payable returns(Match memory) {
        require(msg.value == matchFee, "Pay the Match fee.");
        uint _matchCounter = matchCounter[_category];
        Match memory _match =  matchIndex[_category][_matchCounter];
        require(_match.matchStatus == MatchStatus.PENDING, "The match has started");
        require(!playing[msg.sender], "Finish your match before");
        playing[msg.sender] = true;
        _match.players[1] = msg.sender; // Set Rival
        _match.matchStatus = MatchStatus.STARTED; // Update Match status

        matchIndex[_category][_matchCounter] = _match; // Update Match details


        emit RivalFound(_match.players[0], _category, msg.sender, _matchCounter, block.timestamp);
        return _match;
    }

    // We need to add the resolvematch LOGIC and declare winner and looser.
    function resolveMatch(uint8 _category, uint _matchId) external returns(Match memory) {
        Match memory _match = matchIndex[_category][_matchId];
        require(_match.matchStatus == MatchStatus.STARTED, "The match is not pending");
        // Match Logic. Maybe request NFT URI score for the final result.
        // _match.winner = _winner;
        _match.matchStatus = MatchStatus.ENDED; // Update Match status
        matchIndex[_category][_matchId] = _match; // Update Match details.
        playing[_match.players[0]] = false;
        playing[_match.players[1]] = false;

        // matchIndex[_category][_matchId] = _match;
        // resultsPlayer[_winner][1]++;
        // resultsPlayer[_looser][2]--;

        return _match;
        // emit MatchFinished(address Winner, uint8 Category, address Looser, uint MatchID, uint time);
    }

    function withdrawFunds(uint _amount) external onlyOwner{
        payable(treasuryAddress).transfer(_amount);
    }

    function setMatchFee(uint _fee) external onlyOwner{
        matchFee = _fee;
        emit MatchCommissionSetted(_fee, block.timestamp);
    }

    function setDailyMatchs(uint8 _amount) external onlyOwner{
        dailyMatchs = _amount;
        emit TotalDailyMatchsUpdated(_amount, block.timestamp);
    }

    // Getter for Match details.
    function getMatch(uint8 _category, uint _matchId) public view returns(Match memory){
        return matchIndex[_category][_matchId];
    }

    function getTotalWins(address _player) public view returns(uint){
        return resultsPlayer[_player][1];
    }

    function getTotalLost(address _player) public view returns(uint){
        return resultsPlayer[_player][2];
    }

}
