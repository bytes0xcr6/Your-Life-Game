//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLVault.sol";
import "./YLProxy.sol";
import "./Contest.sol";

contract Tournament {
    IERC721 private ylNFTERC721;
    IERC20 private ylERC20;
    YLProxy private ylProxy;
    YLVault private vaultAddress;
    Contest private contestAddress;
    

    // struct TournamentDetails {
        
    // }


    /// @dev Match struct to store the match info
    struct Match {
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

    constructor(IERC721 _ylNFTERC721, IERC20 _ylERC20, YLProxy _ylProxy, YLVault _vaultAddress, Contest _contestAddress) {
        ylNFTERC721 = _ylNFTERC721;
        ylERC20 = _ylERC20;
        ylProxy = _ylProxy;
        vaultAddress = _vaultAddress;
        contestAddress = _contestAddress;
    }

    function play(address _player1, uint _score1, address _player2, uint _score2, uint8 _category) external onlyOwner{
        require(ylProxy.totalStakedAmount(msg.sender, address(ylERC20)) >= contestAddress.getTournamentFee(), "You need to stake more YLT");
        require(YLVault(vaultAddress).checkElegible(msg.sender, _category) == true, "You are not elegible.");
        
        address winner;

        if(_score1 > _score2) {
            winner = _player1;
        }else if(_score1 < _score2) {
            winner = _player2;
        } else {
            winner = address(0);
        }

        Match memory _match = Match (
            _category,
            [msg.sender, address(0)],
            address(winner)
        );
        matchIndex[_category][matchCounter[_category]] = _match;

        emit MatchCreated(msg.sender, _category, matchCounter[_category], block.timestamp);
        matchCounter[_category]++;
    }

    // function getResult() external view returns (){}

}
