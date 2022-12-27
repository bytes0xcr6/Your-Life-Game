//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLVault.sol";
import "./YLProxy.sol";
import "./Tournament.sol";

contract Contest {
    IERC721 private ylNFTERC721;
    IERC1155 private ylNFTERC1155;
    IERC20 private ylERC20;
    YLProxy private ylProxy;
    YLVault private vaultAddress;
    address private treasuryAddress;
    uint private minTokensStaked;
    uint tournamentFee;
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
    event TournamentCommissionSetted(uint SettedFee, uint SettedTime);
    event NewAdminSetted(address NewAdmin, uint SettedTime);
    event TotalDailyMatchsUpdated(uint8 DailyMatchs, uint SettedTime);
    event MinTokensStakedUpdated(uint MinYLTStaked, uint SettedTime);

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

    function newTournament() external onlyOwner{
        Tournament _newTournament = new Tournament(ylNFTERC721, ylERC20, ylProxy, vaultAddress, Contest(address(this)));
        
    }

    function withdrawFunds(address payable _to, uint _amount) external onlyOwner{
        payable(_to).transfer(_amount);
    }

    function setTournamentFee(uint _fee) external onlyOwner{
        tournamentFee = _fee;
        emit TournamentCommissionSetted(_fee, block.timestamp);
    }

    function setDailyMatchs(uint8 _amount) external onlyOwner{
        dailyMatchs = _amount;
        emit TotalDailyMatchsUpdated(_amount, block.timestamp);
    }

    function setMinStakedToPlay(uint _amount) external onlyOwner{
        minTokensStaked = _amount;
        emit MinTokensStakedUpdated(_amount, block.timestamp);
    }

    function getTournamentFee() external view returns(uint){
        return tournamentFee;
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
