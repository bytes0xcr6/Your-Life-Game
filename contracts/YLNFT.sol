//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IProxy {
    function isMintableAccount(address _address) external view returns (bool);

    function isBurnAccount(address _address) external view returns (bool);

    function isTransferAccount(address _address) external view returns (bool);

    function isPauseAccount(address _address) external view returns (bool);
    
    function getCategory(uint _tokenId) external view returns(string memory);

    function isAthleteAccount(address _address) external view returns (bool);

    function athleteMintCheck(address _address) external view returns (bool);

    function athleteMintStatus(address _address, bool _value) external returns(bool);
    
    function getNFTMarket1Addr() external view returns (address);
    
    function getNFTMarket2Addr() external view returns (address);
    
    function getYLVaultAddr() external view returns(address);

    function getAuctionAddr() external view returns(address);

    function getMarketERC1155Addr() external view returns(address);
}

contract YLNFT is
    ERC721URIStorage,
    EIP712,
    Ownable,
    AccessControl,
    ReentrancyGuard
{
    address payable _ylnft721Owner;
    IProxy public proxy;
    Counters.Counter private _tokenIds;
    bool public yltpause;

    using ECDSA for bytes32;

    bytes32 public constant MINTER_ROLE = keccak256("YLNFT721_ROLE");

    mapping(string => mapping(string => uint256)) private categoryAmount;
    mapping(string => mapping(string => uint256)) private categoryCount;
    mapping(uint => string) private categoryByID;
    mapping(uint256 => uint256) private burnSignature;
    mapping(uint256 => mapping(address => bool)) private burnAddress;

    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        string uri;
    }

    event minted721(address indexed minter, uint256 tokenId, uint256 mintedGas);
    event Burned721(address indexed admin1, uint256 tokenId, uint256 burnedGas);
    event PauseContract(
        address indexed admin,
        address indexed minted721contract,
        uint256 timestamp
    );
    event UnpauseContract(
        address indexed admin,
        address indexed minted721contract,
        uint256 timestamp
    );
    event Transfer721to(address indexed admin, address indexed from, address indexed to, uint256 tokenId);

    constructor(IProxy _proxy)
        ERC721("YourLifeGame NFT", "YLNFT")
        EIP712("LazyNFT-Voucher", "1")
    {
        _ylnft721Owner = payable(msg.sender);
        proxy = _proxy;
        _setupRole(MINTER_ROLE, _ylnft721Owner);
    }

    function setProxyAddress(address _proxyAddress)
        public
        onlyOwner
    {
        proxy = IProxy(_proxyAddress);
    }

    function setPauseContract(bool _yltpause) public returns (bool) {
        require(
            proxy.isPauseAccount(msg.sender),
            "you can't pause this contract, please contact the Admin"
        );
        yltpause = _yltpause;
        if (yltpause == true) {
            emit PauseContract(msg.sender, address(this), block.timestamp);
        } else {
            emit UnpauseContract(msg.sender, address(this), block.timestamp);
        }
        return true;
    }

    //transfer after moderating
    function ylnft721Transfer(address _to, uint256 _tokenId)
        public
        nonReentrant
        returns (bool)
    {
        require(
            proxy.isTransferAccount(msg.sender),
            "you can't transfer YL NFT, please contact the Admin"
        );
        require(getPauseContract() == false, "NFT721 Contract was paused!");
        require(_to != address(0), "Can't transfer NFT721 to address(0)");
        require(ownerOf(_tokenId) == address(this), "Contract haven't this TokenID");

        _transfer(address(this), _to, _tokenId);
        emit Transfer721to(msg.sender, address(this), _to, _tokenId);
        return true;
    }

    //mint
    function createToken(
        string memory tokenURI,
        string memory _sport,
        string memory _cnft
    ) public returns (uint256) {
        uint256 startGas = gasleft();

        require(
            proxy.isMintableAccount(msg.sender) || proxy.isAthleteAccount(msg.sender),
            "you can't mint YLT NFT, please contact the Admin"
        );
        if(proxy.isAthleteAccount(msg.sender) && bytes(_sport).length != 0){
            require(!proxy.athleteMintCheck(msg.sender), "You already minted a sportsman NFT");
        }
        require(
            categoryAmount[_sport][_cnft] >= (categoryCount[_sport][_cnft]) + 1,
            " Overflow! Amount of NFT category"
        );
        require(getPauseContract() == false, "NFT721 Contract was paused!");

        incrementTokenId();
        uint256 newTokenId = getCurrentTokenId();
        _mint(address(this), newTokenId); //NFT is kept in this contract.
        _setTokenURI(newTokenId, tokenURI);
        _setApprovalForAll(address(this), proxy.getNFTMarket1Addr(), true);
        _setApprovalForAll(address(this), proxy.getYLVaultAddr(), true);
        _setApprovalForAll(address(this), proxy.getNFTMarket2Addr(), true);
        _setApprovalForAll(address(this), proxy.getAuctionAddr(), true);        
        _approve(proxy.getAuctionAddr(), newTokenId);

        categoryCount[_sport][_cnft] += 1;

        uint256 gasUsed = startGas - gasleft();

        categoryByID[newTokenId] = _sport;

        emit minted721(msg.sender, newTokenId, gasUsed);

        return newTokenId;
    }

    function getCurrentTokenId() public view returns (uint256) {
        return Counters.current(_tokenIds);
    }

    function incrementTokenId() private {
        Counters.increment(_tokenIds);
    }

    // k. Ability to Withdraw commissions to specific wallet addresses.
    function withdraw(address payable _to, uint256 _value)
        public
        nonReentrant
        onlyOwner
    {
        require(address(this).balance > _value, "Insufficient balance");
        require(getPauseContract() == false, "NFT721 Contract was paused!");
        require(_to != address(0), "Can't transfer Coin to address(0)");

        _to.transfer(_value);
    }

    //burn part
    function burnNFT721(uint256 _tokenId) public returns (bool) {
        uint256 startGas = gasleft();
        require(
            proxy.isBurnAccount(msg.sender),
            "you can't transfer YL NFT, please contact the Admin"
        );
        require(getPauseContract() == false, "NFT721 Contract was paused!");
        require(burnSignature[_tokenId] >= 2, "Multi Signature");

        _burn(_tokenId);
        uint256 gasUsed = startGas - gasleft();
        emit Burned721(msg.sender, _tokenId, gasUsed);
        return true;
    }

    //lazy minting part
    function lazyCreateToken(
        /*NFTVoucher calldata voucher*/
        string memory _tokenURI,
        /*bytes memory signature,*/
        string memory _sport,
        string memory _cnft
    ) public payable returns (uint256) {
        require(
            categoryAmount[_sport][_cnft] >= (categoryCount[_sport][_cnft]) + 1,
            " Overflow! Amount of NFT category"
        );
        require(getPauseContract() == false, "NFT721 Contract was paused!");

        // address signer = _verify(voucher, signature);

        // require(hasRole(MINTER_ROLE, signer), "Signature invalid or unauthorized");
        // require(msg.value >= voucher.minPrice, "Insufficient funds to redeem");
        // _mint(signer, voucher.tokenId);
        incrementTokenId();
        uint256 newTokenId = getCurrentTokenId();
        _mint(_ylnft721Owner, newTokenId);
        // _setTokenURI(voucher.tokenId, voucher.uri);
        _setTokenURI(newTokenId, _tokenURI);
        // _transfer(signer, msg.sender, voucher.tokenId);
        _transfer(_ylnft721Owner, msg.sender, newTokenId);
        _ylnft721Owner.transfer(msg.value);

        categoryCount[_sport][_cnft] += 1;

        // return voucher.tokenId;
        return newTokenId;
    }

    function _hash(NFTVoucher calldata voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "NFTVoucher(uint256 tokenId,uint256 minPrice,string uri)"
                        ),
                        voucher.tokenId,
                        voucher.minPrice,
                        keccak256(bytes(voucher.uri))
                    )
                )
            );
    }

    function _verify(NFTVoucher calldata voucher, bytes memory signature)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);
        return digest.toEthSignedMessageHash().recover(signature);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721)
        returns (bool)
    {
        return
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }

    function burnNFT721Signature(uint256 _tokenId) public returns (uint256) {
        require(proxy.isBurnAccount(msg.sender), "Only SuperAdmin or Admin");
        require(
            burnAddress[_tokenId][msg.sender] == false,
            "Already you signed"
        );
        burnAddress[_tokenId][msg.sender] = true;
        burnSignature[_tokenId] = burnSignature[_tokenId] + 1;

        return burnSignature[_tokenId];
    }

    function getCategory(uint _tokenId) external view returns(string memory){
        return categoryByID[_tokenId];
    }

        function setCategoryAmount(
        string memory _sport,
        string memory _cnft,
        uint256 _amount
    ) public returns (bool) {
        categoryAmount[_sport][_cnft] = _amount;
        return true;
    }

    function deleteCategory(string memory _sport, string memory _cnft)
        public
        returns (bool)
    {
        delete categoryAmount[_sport][_cnft];
        return true;
    }

    function getCategoryCount(string memory _sport, string memory _cnft)
        public
        view
        returns (uint256)
    {
        return categoryCount[_sport][_cnft];
    }

    function getCategoryAmount(string memory _sport, string memory _cnft)
        public
        view
        returns (uint256)
    {
        return categoryAmount[_sport][_cnft];
    }

    function getPauseContract() public view returns (bool) {
        return yltpause;
    }
}
