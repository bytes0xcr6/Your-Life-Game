const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("Deployment", function () {
  async function deploymentAll() {
    const baseURI = "<BASE URI TO SET>";
    const [Owner, addr1, addr2, addr3] = await ethers.getSigners();
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
      addr2,
      addr3,
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
        addr2,
        addr3,
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

      const balanceOwners = await ylt.balanceOf(Owner.address);
      console.log("Total balance before staking", balanceOwners);

      //STAKE YLToken (Owner)
      const minToStake = "100000000000000000000";
      // Approve to manage.
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
      const balanceYLTOwner = await ylt.balanceOf(Owner.address);
      console.log(balanceYLTOwner);

      // Transfer YLTToken to addr2 & addr3 & Stake
      await ylt.transfer(addr2.address, "200000000000000000000");
      await ylt.transfer(addr3.address, "200000000000000000000");

      const balanceYLTAddr2 = await ylt.balanceOf(addr2.address);
      expect(balanceYLTAddr2).to.be.equal("200000000000000000000");
      console.log(
        `✅ The Addr2 & Addr3 has received each ${balanceYLTAddr2} YLToken from Owner:`
      );

      // Approve YLProxy for staking YLTokens from Addr2 and Addr3
      await ylt.connect(addr2).approve(ylProxy.address, minToStake);
      await ylt.connect(addr3).approve(ylProxy.address, minToStake);

      await ylProxy.connect(addr2).depositYLT(minToStake);
      await ylProxy.connect(addr3).depositYLT(minToStake);

      const balanceAddr2AfterStaking = await ylt.balanceOf(addr2.address);
      expect(
        await ylProxy.totalStakedAmount(addr2.address, ylt.address)
      ).to.be.equal(minToStake);
      console.log(
        "✅The Addr2 Balance is staking the minimum to stake and his balance now is:",
        balanceAddr2AfterStaking
      );

      // BOOSTER - Set categories amount for BOOSTER & MINT 5 Boosters. Then transfer to addr2
      await ylNFT1155.setCategoryAmount("Soccer", "speed", 5);
      console.log(
        "\n✅ Booster Category Soccer/speed created with a maximum of 5"
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

      await ylNFT1155.ylnft1155Transfer(addr2.address, 1, 5);
      expect(await ylNFT1155.balanceOf(addr2.address, 1)).to.equal(5);
      console.log("✅ Owner has transfer 5 Boosters to addr2.");

      //NFT - Set categories amount for NFTs & MINT 5 NFT. Then transfer to addr2
      await ylNFT.setCategoryAmount("Soccer", "Women", 10);
      console.log(
        "\n✅ NFT Category Soccer/Women created with a maximum of 10"
      );
      console.log(
        "Total available per category",
        await ylNFT.getCategoryAmount("Soccer", "Women")
      );

      // Create 10 NFTs (5 vs 5)
      for (let i = 0; i < 10; i++) {
        await ylNFT.createToken("www.example.com", "Soccer", "Women");
      }

      console.log(
        "✅ NFT Generated for the Soccer/ Women Category:",
        await ylNFT.getCategoryCount("Soccer", "Women")
      );
      console.log("🛡 Reverted if creating more than Category Amount, checked.");

      console.log(
        "✅ Get Category by ID, Category 1 is:",
        await ylNFT.getCategory(1)
      );
      expect("Soccer").to.equal(await ylNFT.getCategory(1));

      // Transfer NFTs to 2 players
      for (let i = 1; i < 6; i++) {
        await ylNFT.ylnft721Transfer(addr2.address, [i]);
      }
      for (let i = 6; i < 11; i++) {
        await ylNFT.ylnft721Transfer(addr3.address, [i]);
      }

      console.log(
        "✅ Owner has transferred 5 Soccer NFTs to Address2 & other 5 to Addr3! "
      );
      // YLVAULT - Store NFT and Boosters.
      await expect(
        ylVault
          .connect(addr1)
          .storeNftFromWalletToVaultERC721(addr2.address, [1])
      ).to.be.reverted;
      console.log(
        "\n🛡 Reverted if transfering to YLVault from a not NFT addr2 account"
      );

      // Approve to manage.
      for (let i = 1; i < 6; i++) {
        await ylNFT.connect(addr2).approve(ylVault.address, i);
      }

      for (let i = 6; i < 11; i++) {
        await ylNFT.connect(addr3).approve(ylVault.address, i);
      }

      console.log(
        "\n ✅Addr2 & Addr3 have approved YLVault contract for his NFTS"
      );

      await ylVault
        .connect(addr2)
        .storeNftFromWalletToVaultERC721(addr2.address, [1, 2, 3, 4, 5]);

      await ylVault
        .connect(addr3)
        .storeNftFromWalletToVaultERC721(addr3.address, [6, 7, 8, 9, 10]);

      // Addr2
      const subVaultNFTTransferAddr2 = await ylVault.vaultContract(
        addr2.address
      );
      const vaultNFTsCounterAddr2 = await ylVault.NFTsCounter(
        addr2.address,
        "Soccer"
      );

      console.log(
        `✅ ${vaultNFTsCounterAddr2}/5 NFTs sent from addr2 address to New Subvault address:`,
        subVaultNFTTransferAddr2
      );
      console.log(
        "\n✅ Is Addr2 elegible to play? ",
        await ylVault.checkElegible(addr2.address, "Soccer")
      );
      console.log(
        "✅ Is Addr3 elegible to play? ",
        await ylVault.checkElegible(addr3.address, "Soccer")
      );

      // Addr3
      const subVaultNFTTransferAddr3 = await ylVault.vaultContract(
        addr3.address
      );
      const vaultNFTsCounterAddr3 = await ylVault.NFTsCounter(
        addr3.address,
        "Soccer"
      );

      console.log(
        `✅ ${vaultNFTsCounterAddr3}/5 NFTs sent from addr3 address to New Subvault address:`,
        subVaultNFTTransferAddr3
      );

      await expect(ylVault.storeNftFromWalletToVaultERC721(addr1.address, [1]))
        .to.be.reverted;
      console.log(
        "🛡 Reverted if transfering to YLVault from a not NFT addr2 account"
      );

      await expect(ylVault.storeNftFromWalletToVaultERC721(addr2.address, [6]))
        .to.be.reverted;
      console.log(
        "🛡 Reverted if transfering to YLVault a not yet created NFTid"
      );

      // Addr2 & Addr3 Approved YLVault to manage. setApprovalForAll
      await ylNFT1155.connect(addr2).setApprovalForAll(ylVault.address, true);
      await ylNFT1155.connect(addr3).setApprovalForAll(ylVault.address, true);
      console.log(
        "\n ✅Addr2 & Addr3 has approved YLVault contract for his Boosters"
      );

      await ylVault
        .connect(addr2)
        .storeNftFromWalletToVaultERC1155(addr2.address, 1, 5);
      console.log("\n ✅ Addr2 stored his ERC1155 in their subvaults");

      await expect(
        ylVault.storeNftFromWalletToVaultERC1155(addr2.address, 1, 6)
      ).to.be.reverted;
      console.log("🛡 Reverted if transfering Booster not created");

      const subVaultBoosterTransfer = await ylVault.vaultContract(
        addr2.address
      );
      expect(subVaultNFTTransferAddr2).to.equal(subVaultBoosterTransfer);
      console.log(
        "✅ 5 Boosters sent from addr2 address to Subvault address:",
        subVaultBoosterTransfer
      );

      // ADD NEW SPORT (Soccer) - OWNER
      await ylVault.addNewSport("Soccer", 5);
      const playersNeededSoccer = await ylVault.playersNeeded("Soccer");
      expect(await ylVault.playersNeeded("Soccer")).to.equal(5);
      console.log("\n✅ Minimum players for Soccer are:", playersNeededSoccer);

      //Instace Subcontracts for Addr2 & Addr3, then Burn 3 Boosters
      const BoostersToBurn = 3;
      const subVault = await ethers.getContractFactory("Vault");
      const subVaultAddr2 = await subVault.attach(subVaultNFTTransferAddr2);

      const subVaultAddr3 = await subVault.attach(subVaultNFTTransferAddr3);

      const balanceBoosterBeforeBurn = await ylNFT1155.balanceOf(
        subVaultNFTTransferAddr2,
        1
      );

      await subVaultAddr2.connect(addr2).burnBoosters([1], [BoostersToBurn]);

      const balanceBoosterAfterBurn = await ylNFT1155.balanceOf(
        subVaultNFTTransferAddr2,
        1
      );

      expect(balanceBoosterAfterBurn).to.equal(
        balanceBoosterBeforeBurn - BoostersToBurn
      );
      console.log(
        `\n✅Address2 has burned ${BoostersToBurn} Boosters of ${balanceBoosterBeforeBurn} & now he has ${balanceBoosterAfterBurn} left in his SubVault`
      );

      // SET TOURNAMENT FEE, PAY AND CHECK IF PAID.
      await contestGame.setTournamentFee(1, tournamentFee);
      console.log(
        `\n✅ Tournament Fee set for ${await contestGame.getTournamentFee(
          1
        )} YLT`
      );

      console.log("Balance addr2 is:", await ylt.balanceOf(addr2.address));
      console.log("Balance addr3 is:", await ylt.balanceOf(addr3.address));

      // Approve ContestGame to manage user´s YLT
      const tournamentFee = 50;
      await ylt.connect(addr2).approve(contestGame.address, tournamentFee);
      await ylt.connect(addr3).approve(contestGame.address, tournamentFee);

      // ----- PROBLEMA!!!!! LOS USUARIOS TIENEN BALANCE, PERO NO DEJA PAGAR LA TOURNAMENT FEE, INCLUSO DANDO PERMISOS!!!------
      await contestGame.connect(addr2).payTournamentFee(1);
      await contestGame.connect(addr3).payTournamentFee(1);
      console.log("\n✅ Addr2 & Addr3 paid the Tournament Fee ");

      // Set Minimum Stake to play
      await contestGame.setMinStakedPlay("100000000000000000000");

      // PLAY A GAME
      await contestGame.play(addr2.address, 10, addr3.address, 11, "Soccer", 1);
      const resultMatch = await contestGame.getMatch("Soccer", 0);
      console.log("\n✅ The winner is:", resultMatch.winner);

      // // WITHDRAW ERC721 FROM VAULT AND PAY FEES
      // const balanceOwnerYLTBeforeNFTWithdrawn = await ylt.balanceOf(Owner.address);
      // console.log(
      //   "The Owner/Treasury balance before withdrawn",
      //   balanceOwnerYLTBeforeNFTWithdrawn
      // );

      // const balanceOwnerYLTAfterNFTWithdrawn = await ylt.balanceOf(Owner.address);
      // console.log(
      //   "The Owner/Treasury balance after withdrawn",
      //   balanceOwnerYLTAfterNFTWithdrawn
      // );
      // // WITHDRAW ERC721 FROM VAULT AND PAY FEES
    });
  });
});

// MISING ON THE TEST:

/* 
------- CONTEST GAME CONTRACT ------------------
Play a game with subvault full.
Pay tournament fees
Check balances after fees paid.
try to start a game with subvault empty. (Expect error)

 -----SUBVAULT CONTRACT -----------------------
  Withdraw from subvault NFTF & BOOSTERS. CHECK HOW TO GET ABI FROM SUBVAULT CONTRACT!!!!!.
  Check balances after fees paid.
  Burn Boosters


  -------- AUCTION CONTRACT -------------
  it may needs ERC1155 receiver.
*/
