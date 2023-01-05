const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("Deployment", function () {
  async function deploymentAll() {
    const baseURI = "<BASE URI TO SET>";
    const [Owner, addr1] = await ethers.getSigners();
    console.log("Contracts deployer / Owner:", Owner.address);

    // DEPLOY - YLT Token Contract
    const YLT = await hre.ethers.getContractFactory("YLT");
    const ylt = await YLT.deploy();
    await ylt.deployed();
    console.log("YLT contract deployed to:", ylt.address);

    // DEPLOY - YL Proxy Contract
    const YLProxy = await hre.ethers.getContractFactory("YLProxy");
    const ylProxy = await YLProxy.deploy(ylt.address);
    await ylProxy.deployed();
    console.log("YLProxy contract deployed to:", ylProxy.address);

    // DEPLOY - YLNFT1155 Contract (WE NEED TO SET THE MARKET ADDRESS BY FUNCTION)
    const YLNFT1155 = await hre.ethers.getContractFactory("YLNFT1155");
    const ylNFT1155 = await YLNFT1155.deploy(baseURI, ylProxy.address);
    await ylNFT1155.deployed();
    console.log("YLNFT1155 contract deployed to:", ylNFT1155.address);

    // DEPLOY - Marketplace NFT1155 Contract
    const YL1155Marketplace = await hre.ethers.getContractFactory(
      "YL1155Marketplace"
    );
    const yl1155Marketplace = await YL1155Marketplace.deploy(
      ylNFT1155.address,
      ylProxy.address
    );
    await yl1155Marketplace.deployed();
    console.log(
      "YLNFT1155 Marketplace contract deployed to:",
      yl1155Marketplace.address
    );

    // DEPLOY - ERC721 Contract (WE NEED TO SET THE MARKET ADDRESS BY FUNCTION)
    const YLNFT = await hre.ethers.getContractFactory("YLNFT");
    const ylNFT = await YLNFT.deploy(ylProxy.address);
    await ylNFT.deployed();
    console.log("YLNFT contract deployed to:", ylNFT.address);

    // DEPLOY - Marketplace ERC721 Contract (2)
    const YLNFTMarketplace2 = await hre.ethers.getContractFactory(
      "YLNFTMarketplace2"
    );
    const ylNFTMarketplace2 = await YLNFTMarketplace2.deploy(ylNFT.address);
    await ylNFTMarketplace2.deployed();
    console.log(
      "YLFTMarketplace2 contract deployed to:",
      ylNFTMarketplace2.address
    );

    // DEPLOY - Marketplace ERC721 Contract (1)
    const YLNFTMarketplace1 = await hre.ethers.getContractFactory(
      "YLNFTMarketplace1"
    );
    const ylNFTMarketplace1 = await YLNFTMarketplace1.deploy(
      ylNFT.address,
      ylProxy.address,
      ylNFTMarketplace2.address
    );
    await ylNFTMarketplace1.deployed();
    console.log(
      "YLFTMarketplace1 contract deployed to:",
      ylNFTMarketplace1.address
    );

    // DEPLOY - YLVault FABRIC contract (Imports substorage Vault.sol)
    const YLVault = await hre.ethers.getContractFactory("YLVault");
    const ylVault = await YLVault.deploy(
      ylNFT.address,
      ylNFT1155.address,
      ylt.address
    );
    ylVault.deployed();
    console.log("YLVault contract deployed to:", ylVault.address);

    // DEPLOY - Auction contract
    const Auction = await ethers.getContractFactory("Auction");
    const auction = await Auction.deploy(
      ylNFT.address,
      ylNFT1155.address,
      ylNFTMarketplace1.address,
      ylNFTMarketplace2.address,
      ylt.address
    );
    await auction.deployed();
    console.log("Auction contract deployed to:", auction.address);

    // DEPLOY - ContestGame Contract
    const ContestGame = await hre.ethers.getContractFactory("ContestGame");
    const contestGame = await ContestGame.deploy(
      ylNFT.address,
      ylNFT1155.address,
      ylt.address,
      ylProxy.address,
      ylVault.address
    );
    await contestGame.deployed();
    console.log("ContestGame contract deployed to:", contestGame.address);

    console.log("✅ 10 contracts deployed!!");
    return {
      Owner,
      ylt,
      ylNFT1155,
      yl1155Marketplace,
      ylNFTMarketplace1,
      ylNFTMarketplace2,
      contestGame,
      auction,
      ylNFT,
      ylProxy,
      ylVault,
      addr1,
    };
  }

  describe("Testing", async function () {
    it("Whole Workflow", async function () {
      const {
        Owner,
        ylt,
        ylNFT1155,
        yl1155Marketplace,
        ylNFTMarketplace1,
        ylNFTMarketplace2,
        contestGame,
        auction,
        ylNFT,
        ylProxy,
        ylVault,
        addr1,
      } = await loadFixture(deploymentAll);

      // set MARKETplace 1155 Address in the ERC1155 contract
      await ylNFT1155.setMarketAddress(yl1155Marketplace.address);

      // set YLVault address in the ERC1155 contract
      await ylNFT1155.setYLVaultAddress(ylVault.address);

      // SET MARKETplaces-721 (1 & 2) Addresses in the ERC721 contract
      await ylNFT.setMarketAddress1(ylNFTMarketplace1.address);
      await ylNFT.setMarketAddress2(ylNFTMarketplace2.address);
      await ylNFT.setYLVault(ylVault.address);

      expect(await ylNFT1155.marketAddress()).to.equal(
        yl1155Marketplace.address
      );
      console.log("\n✅ Marketplace1155 set in the ERC1155 contract");
      expect(await ylNFT.marketAddress1()).to.equal(ylNFTMarketplace1.address);
      expect(await ylNFT.marketAddress2()).to.equal(ylNFTMarketplace2.address);
      console.log("✅ Marketplaces721 (1 & 2) set in the ERC721 contract");

      // // Pause and unpause AUCTION
      // // console.log(yl1155Marketplace.pauseStatus[0]);
      // await yl1155Marketplace.adminPauseUnpause(0);
      // console.log(await yl1155Marketplace.pauseStatus(0));
      // // expect(await yl1155Marketplace.pauseStatus(0)).to.equal(true);
      // console.log("✅ Auction 0 Paused");

      //STAKE YLToken
      const minToStake = "100000000000000000000";
      await ylt.approve(ylProxy.address, minToStake);
      await ylProxy.depositYLT(minToStake);
      expect(
        await ylProxy.totalStakedAmount(Owner.address, ylt.address)
      ).to.equal(minToStake);
      console.log(
        "✅ The Owner has staked YLT:",
        ethers.utils.formatEther(
          await ylProxy.totalStakedAmount(Owner.address, ylt.address)
        )
      );

      // BOOSTER - Set categories amount for BOOSTER & Create Boosters.
      await ylNFT1155.setCategoryAmount("Soccer", "speed", 5);
      console.log(
        "✅ Booster Category Soccer/speed created with a maximum of 5"
      );

      await expect(
        ylNFT1155
          .connect(addr1)
          .create1155Token("www.world.com", "Soccer", "speed", 5)
      ).to.be.reverted;
      console.log("\n🛡Reverted if creating from not Admin account.");

      await ylNFT1155.create1155Token("www.example.com", "Soccer", "speed", 5);
      const nftBalanceOwner = await ylNFT1155.balanceOf(Owner.address, 1);
      console.log(
        "✅ Boosters for Category Soccer/speed created:",
        nftBalanceOwner
      );

      await expect(
        ylNFT1155.create1155Token("www.example.com", "Soccer", "speed", 3)
      ).to.be.reverted;
      console.log("🛡 Reverted if Overflow total per category.");

      //NFT - Set categories amount for NFTs & Create 5 NFT.
      await ylNFT.setCategoryAmount("Tennis", "Women", 5);
      console.log("\n✅ NFT Category Tennis/Women created with a maximum of 5");
      console.log(
        "Total available per category",
        await ylNFT.getCategoryAmount("Tennis", "Women")
      );
      await ylNFT.createToken("www.example.com", "Tennis", "Women");
      await ylNFT.createToken("www.example.com", "Tennis", "Women");
      await ylNFT.createToken("www.example.com", "Tennis", "Women");
      await ylNFT.createToken("www.example.com", "Tennis", "Women");
      await ylNFT.createToken("www.example.com", "Tennis", "Women");

      console.log(
        "✅ NFT Generated for the Tennis/ Women Category:",
        await ylNFT.getCategoryCount("Tennis", "Women")
      );
      console.log("🛡 Reverted if creating more than Category Amount, checked.");

      console.log(
        "✅ Get Category by ID, Category 1 is:",
        await ylNFT.getCategory(1)
      );
      expect("Tennis").to.equal(await ylNFT.getCategory(1));

      // YLVAULT - Store NFT and Boosters.
      await expect(
        ylVault
          .connect(addr1)
          .storeNftFromWalletToVaultERC721(Owner.address, [1])
      ).to.be.reverted;
      console.log(
        "\n🛡 Reverted if transfering to YLVault from a not NFT Owner account"
      );

      await ylVault.storeNftFromWalletToVaultERC721(
        Owner.address,
        [1, 2, 3, 4, 5]
      );

      const subVaultNFTTransfer = await ylVault.vaultContract(Owner.address);
      const vaultNFTsCounter = await ylVault.NFTsCounter(
        Owner.address,
        "Tennis"
      );

      console.log(
        `✅ ${vaultNFTsCounter}/5 NFTs sent from Owner address to New Subvault address:`,
        subVaultNFTTransfer
      );

      await expect(ylVault.storeNftFromWalletToVaultERC721(addr1.address, [1]))
        .to.be.reverted;
      console.log(
        "🛡 Reverted if transfering to YLVault from a not NFT Owner account"
      );

      await expect(ylVault.storeNftFromWalletToVaultERC721(Owner.address, [6]))
        .to.be.reverted;
      console.log(
        "🛡 Reverted if transfering to YLVault a not yet created NFTid"
      );

      await ylVault.storeNftFromWalletToVaultERC1155(Owner.address, 1, 5);
      await expect(
        ylVault.storeNftFromWalletToVaultERC1155(Owner.address, 1, 1)
      ).to.be.reverted;
      console.log("🛡 Reverted if transfering Booster not created");

      const subVaultBoosterTransfer = await ylVault.vaultContract(
        Owner.address
      );
      expect(subVaultNFTTransfer).to.equal(subVaultBoosterTransfer);
      console.log(
        "✅ 5 Boosters sent from Owner address to Subvault address:",
        subVaultBoosterTransfer
      );

      // WITHDRAW ERC721 FROM VAULT AND PAY FEES

      // WITHDRAW ERC721 FROM VAULT AND PAY FEES
    });
  });
});

// MISING ON THE TEST:
/* 
 -----SUBVAULT CONTRACT -----------------------
  Withdraw from subvault NFTF & BOOSTERS. CHECK HOW TO GET ABI FROM SUBVAULT CONTRACT!!!!!.
  Check balances after fees paid.
  Burn Booster
  ------- CONTEST GAME CONTRACT ------------------
  Play a game with subvault full.
  Pay tournament fees
  Check balances after fees paid.
  try to start a game with subvault empty. (Expect error)
  -------- AUCTION CONTRACT -------------
  it may needs ERC1155 receiver.
*/
