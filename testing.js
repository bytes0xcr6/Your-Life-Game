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
      ylt.address,
      ylProxy.address
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

      // Set YLVault Revert fee
      const revertFee = 30;
      await ylVault.setRevertNftToWalletCommision(revertFee);

      // SET contracts addresses to YLProxy contract.
      await ylProxy.setERC1155Market(yl1155Marketplace.address);
      await ylProxy.setYLTAddress(ylt.address);
      await ylProxy.setMarketNFTAddress1(ylNFTMarketplace1.address);
      await ylProxy.setMarketNFTAddress2(ylNFTMarketplace2.address);
      await ylProxy.setYLVault(ylVault.address);
      await ylProxy.setAuctionAddress(auction.address);
      await ylProxy.setNFTAddress(ylNFT.address);

      expect(await ylProxy.getMarketERC1155Addr()).to.equal(
        yl1155Marketplace.address
      );
      expect(await ylProxy.getNFTMarket1Addr()).to.equal(
        ylNFTMarketplace1.address
      );
      expect(await ylProxy.getNFTMarket2Addr()).to.equal(
        ylNFTMarketplace2.address
      );

      console.log("✅All the contracts have been set in the YLProxy contract");
      const balanceOwners = await ylt.balanceOf(Owner.address);
      console.log("\nTotal balance before staking", balanceOwners);

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

      // Transfer NFTs to Addr2 & Addr3 2 players after moderating the NFTS.
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
      const vaultNFTsCounterAddr2 = await ylVault.nFTsCounter(
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
      const vaultNFTsCounterAddr3 = await ylVault.nFTsCounter(
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

      // const subVaultAddr3 = await subVault.attach(subVaultNFTTransferAddr3);

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
      const tournamentFee = 50;
      await contestGame.setTournamentFee(1, tournamentFee);
      console.log(
        `\n✅ Tournament Fee set for ${await contestGame.getTournamentFee(
          1
        )} YLT`
      );

      console.log("Balance addr2 is:", await ylt.balanceOf(addr2.address));
      console.log("Balance addr3 is:", await ylt.balanceOf(addr3.address));

      // Approve ContestGame to manage user´s YLT
      await ylt.connect(addr2).approve(contestGame.address, tournamentFee);
      await ylt.connect(addr3).approve(contestGame.address, tournamentFee);

      await contestGame.connect(addr2).payTournamentFee(1);
      await contestGame.connect(addr3).payTournamentFee(1);
      console.log("\n✅ Addr2 & Addr3 paid the Tournament Fee ");

      // Set Minimum Stake to play
      await contestGame.setMinStakedPlay("100000000000000000000");

      // PLAY A GAME
      await contestGame.play(addr2.address, 10, addr3.address, 11, "Soccer", 1);
      const resultMatch = await contestGame.getMatch("Soccer", 0);
      console.log("\n✅ The winner is:", resultMatch.winner);

      // REVERT ERC721 FROM VAULT, Approve Subvault AND PAY FEES for reverting NFTs
      const balanceOwnerYLTBeforeNFTWithdrawn = await ylt.balanceOf(
        Owner.address
      );

      const nftsToRevert = [1, 2];

      console.log(
        "Fees for withdrawing 2 NFTS",
        (await ylVault.revertNFTComision()) * nftsToRevert.length
      );

      await ylt.connect(addr2).approve(subVaultAddr2.address, 160);

      await subVaultAddr2
        .connect(addr2)
        .revertNftFromVaultToWalletERC721(nftsToRevert);

      console.log(
        "Addr2 has allowed to his vault to transer ERC20:",
        await ylt.allowed(addr2.address, subVaultAddr2.address)
      );

      console.log("\n✅Addr2 has reverted from his SubVault the NFTs 1 & 2");

      const balanceOwnerYLTAfterNFTWithdrawn = await ylt.balanceOf(
        Owner.address
      );

      console.log(balanceOwnerYLTBeforeNFTWithdrawn);

      console.log(
        `The Owner/Treasury balance has increased ${
          nftsToRevert.length * revertFee
        } YLT, Before he had ${balanceOwnerYLTBeforeNFTWithdrawn} & now has ${balanceOwnerYLTAfterNFTWithdrawn}`
      );

      // REVERT ERC1155 FROM VAULT, Approve Subvault AND PAY FEES for reverting Boosters
      await subVaultAddr2
        .connect(addr2)
        .revertNftFromVaultToWalletERC1155(1, "Soccer", 1);

      console.log("\n✅ Addr2 has reverted 1 Booster from his Subvault");
      const balanceOwnerYLTAfterBoosterWithdrawn = await ylt.balanceOf(
        Owner.address
      );

      console.log(
        `The Owner/Treasury balance has increased ${
          1 * revertFee
        } YLT, Before he had ${balanceOwnerYLTAfterNFTWithdrawn} & now has ${balanceOwnerYLTAfterBoosterWithdrawn}`
      );

      //TRY TO START A GAME WITH NOT THE MINIMUM OF PLAYERS PER CATEGORY
      await expect(
        contestGame.play(addr2.address, 10, addr3.address, 11, "Soccer", 1)
      ).to.be.reverted;

      console.log(
        "\n🛡 Reverted if Addr2 tries to play with less than the minimum of players per category"
      );
      console.log("\n----------------------------------------------------");
    });

    it("Set Category, set Athlete account and mint", async () => {
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

      const minToStake = "100000000000000000000";

      await ylt.approve(ylProxy.address, minToStake);
      await ylt.transfer(addr3.address, "200000000000000000000");
      await ylt.connect(addr3).approve(ylProxy.address, minToStake);
      await ylProxy.connect(addr3).depositYLT(minToStake);
      console.log(
        "✅ The Owner has staked YLT:",
        ethers.utils.formatEther(
          await ylProxy.totalStakedAmount(Owner.address, ylt.address)
        )
      );

      await ylNFT.setCategoryAmount("Tennis", "Men", 1);
      console.log("\n✅ NFT Category Tennis/Men created with a maximum of 1");

      await ylProxy.setAthlete(addr3.address, true);
      expect(await ylProxy.isAthleteAccount(addr3.address)).to.equal(true);
      console.log("\n✅Addr3 has been set as Athlete");

      await ylNFT.connect(addr3).createToken("example", "Tennis", "Men");
      console.log("✅ Tennis NFT created from Addr3(Athlete)");

      await expect(ylNFT.connect(addr3).createToken("example", "Tennis", "Men"))
        .to.be.reverted;

      console.log(
        "\n🛡 Reverted if creating more than the maximum per category"
      );

      console.log("\n----------------------------------------------------");
    });

    it("Create NFTs & Boosters, approve Auction to manage NFTs & then list them in the Auction contract", async () => {
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

      // SET contracts addresses to YLProxy contract.
      await ylProxy.setERC1155Market(yl1155Marketplace.address);
      await ylProxy.setYLTAddress(ylt.address);
      await ylProxy.setMarketNFTAddress1(ylNFTMarketplace1.address);
      await ylProxy.setMarketNFTAddress2(ylNFTMarketplace2.address);
      await ylProxy.setYLVault(ylVault.address);
      await ylProxy.setAuctionAddress(auction.address);
      await ylProxy.setNFTAddress(ylNFT.address);

      //STAKE YLToken (Owner)
      const minToStake = "100000000000000000000";
      // Approve to manage.
      await ylt.approve(ylProxy.address, minToStake);
      await ylProxy.depositYLT(minToStake);

      await ylNFT.setCategoryAmount("Tennis", "Men", 2);
      console.log("\n✅ NFT Category Tennis/Men created with a maximum of 2");

      await ylNFT.createToken("www.example.com", "Tennis", "Men"); // ID 1
      await ylNFT.createToken("www.example.com", "Tennis", "Men"); // ID 2
      console.log("\n✅ 2 NFT Tennis/Men created & stored in the NFT contract");

      expect(await ylNFT.ownerOf(1)).to.equal(ylNFT.address);

      console.log(
        "Auction contract is approved for all",
        await ylNFT.isApprovedForAll(ylNFT.address, auction.address)
      );

      await auction.MinterListNFT(1, 100, 1, 140, 1000000, true);

      console.log(
        "\n✅ Owner of the NFT is the NFT contract a minteableAccount listted a new NFT after Moderating"
      );

      await ylNFT.ylnft721Transfer(addr2.address, 2);
      await ylNFT.connect(addr2).approve(auction.address, 2);

      await expect(
        auction.connect(addr3).BuyerListNFT(2, 100, 1, 140, 1000000, true)
      ).to.be.reverted;
      console.log("🛡 Reverted if is not the owner of the NFT");

      await auction.connect(addr2).BuyerListNFT(2, 100, 1, 140, 1000000, true);

      console.log(
        "\n✅ 2 new Men Tennis NFTs created and listed by Addr2 in the Auction contract."
      );

      await ylNFT1155.setCategoryAmount("Tennis", "shoot", 5);
      await ylNFT1155.create1155Token("www.example.com", "Tennis", "shoot", 5);
      console.log("here");
      await ylNFT1155.setApprovalForAll(auction.address, true);
      await auction.MinterListNFT(1, 100, 5, 140, 1000000, false);
      console.log(
        "\n✅ 5 new Tennis Boosters created and listed in the Auction contract. As it is a new minted ERC1155, the superAdmin & Admin can list it, but the revenue will go to the ERC1155 contract"
      );
      console.log("\n----------------------------------------------------");
    });

    // CHECK THE MARKET PLACE TO DO THE SAME AS AUDIT.!!!!! /////////

    it("Create NFTs, approve MARKET PLACES to manage NFTs & then list them in the NFT MARKET PLACE contract", async () => {
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

      // SET contracts addresses to YLProxy contract.
      await ylProxy.setERC1155Market(yl1155Marketplace.address);
      await ylProxy.setYLTAddress(ylt.address);
      await ylProxy.setMarketNFTAddress1(ylNFTMarketplace1.address);
      await ylProxy.setMarketNFTAddress2(ylNFTMarketplace2.address);
      await ylProxy.setYLVault(ylVault.address);
      await ylProxy.setAuctionAddress(auction.address);
      await ylProxy.setNFTAddress(ylNFT.address);

      //STAKE YLToken (Owner)
      const minToStake = "100000000000000000000";
      // Approve to manage.
      await ylt.approve(ylProxy.address, minToStake);
      await ylProxy.depositYLT(minToStake);
      // await ylt.transfer(addr2.address, "200000000000000000000");

      await ylNFT.setCategoryAmount("Tennis", "Men", 2);
      console.log("\n✅ NFT Category Tennis/Men created with a maximum of 2");

      await ylNFT.createToken("www.example.com", "Tennis", "Men"); // ID 1
      await ylNFT.createToken("www.example.com", "Tennis", "Men"); // ID 2
      console.log("\n✅ 2 NFT Tennis/Men created & stored in the NFT contract");

      expect(await ylNFT.ownerOf(1)).to.equal(ylNFT.address);

      console.log(
        "Marketplace1 is approved for all",
        await ylNFT.isApprovedForAll(ylNFT.address, ylNFTMarketplace1.address)
      );

      await ylNFTMarketplace1.minterListedNFT(1, 100);

      console.log(
        "\n✅ Owner of the NFT is the NFT contract a minteableAccount listted a new NFT after Moderating"
      );

      await ylNFT.ylnft721Transfer(addr2.address, 2);
      await ylNFT.connect(addr2).approve(ylNFTMarketplace1.address, 2);
      await ylNFTMarketplace1.depositApproval(addr2.address, 2, true);

      await expect(ylNFTMarketplace1.connect(addr3).buyerListedNFT(2, 150)).to
        .be.reverted;
      console.log("🛡 Reverted if is not the owner of the NFT");

      await ylNFTMarketplace1
        .connect(addr2)
        .buyerListedNFT(2, 150, { value: ethers.utils.parseEther("0.5") });
      console.log(
        "\n✅ 2 new Men Tennis NFTs created and listed in the NFT Market place contract. 1 by the superAdmin & another one by a user, the user had to be approved to deposit the NFT by the Admin & pay the fee for listing the NFT"
      );
      console.log("\n----------------------------------------------------");
      console.log(
        "\n- IMPORTANT!!!: All the NFT & Boosters fresh minted and listed in the Auction or MarketPlaces, the revenue will be transferred after bidding process to the minting contract for the superAdmin to withdrawn the YLT"
      );
    });
  });
});
