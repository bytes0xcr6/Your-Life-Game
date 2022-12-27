//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLVault.sol";

contract Contest is Ownable {
    IERC721 private ylNFTERC721;
    IERC1155 private ylNFTERC1155;
    IERC20 private ylERC20;
    YLVault private treasuryAddress;

    enum MatchStatus{ PENDING, STARTED, ENDED }

    /// @dev Match struct to store the match info
    struct Match {
        MatchStatus matchStatus; /// @param matchStatus enum to indicate battle status
        uint8 category; /// @param SportCategory 1- Footbal, 2- Bastket, etc
        address[2] players; /// @param players address array representing players in this battle
        address winner; /// @param winner winner address
    }
    
    // Index for the won and lost matchs per address. 1- Won matchs, 2- Lost matchs.
    mapping(address => mapping(uint8 => uint)) resultsGamer; 
    // SportCategory => MatchCounter => MatchInfo
    mapping(uint8 => mapping(uint => Match)) matchIndex;
    mapping(address => bool) playing;
    // SportCategory => MatchCounter
    mapping(uint8 => uint) matchCounter;

    event MatchCreated(address GameCreator, uint8 Category, uint MatchID, uint time);
    event RivalFound(address GameCreator, uint8 Category, address Rival, uint MatchID, uint time);
    event MatchFinished(address Winner, uint8 Category, address Looser, uint MatchID, uint time);

    constructor(IERC721 _ylNFTERC721, IERC1155 _ylNFTERC1155, IERC20 _ylERC20, YLVault _treasuryAddress) {
        ylNFTERC721 = _ylNFTERC721;
        ylNFTERC1155 = _ylNFTERC1155;
        ylERC20 = _ylERC20;
        treasuryAddress = _treasuryAddress;
    }

    /// @dev Creates a new match.
    /// @param _category match; set by player
    function createMatch(uint8 _category) external returns(Match memory){
        require(YLVault(treasuryAddress).checkElegible(msg.sender, _category) == true, "You are not elegible.");
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
    function joinMatch(uint8 _category) external returns(Match memory) {
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

    function resolveMatch(uint8 _category, uint _matchId) external returns(Match memory) {
        Match memory _match = matchIndex[_category][_matchId];
        require(_match.matchStatus == MatchStatus.STARTED, "The match is not pending");
        // Match Logic. Maybe request NFT URI score for the final result.
        // _match.winner = _winner;
        _match.matchStatus = MatchStatus.ENDED; // Update Match status
        matchIndex[_category][_matchId] = _match; // Update Match details.
        playing[_match.players[0]] = false;
        playing[_match.players[1]] = false;


        return _match;
        // emit MatchFinished(address Winner, uint8 Category, address Looser, uint MatchID, uint time);
    }

    // Getter for Match details.
    function getMatch(uint8 _category, uint _matchId) public view returns(Match memory){
        return matchIndex[_category][_matchId];
    }


}
    // EXAMPLE P2E
// https://github.com/adrianhajdin/project_web3_battle_game/blob/main/web3/contracts/AvaxGods.sol

    //   /// @dev internal function to generate random number; used for Match Card Attack and Defense Strength
    // function _createRandomNum(uint256 _max, address _sender) internal view returns (uint256 randomValue) {
    //     uint256 randomNum = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _sender)));

    //     randomValue = randomNum % _max; 
    //     if(randomValue == 0) {
    //     randomValue = _max / 2;
    //      }
    //      return randomValue;
    //  } 