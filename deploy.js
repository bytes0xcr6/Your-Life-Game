// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const baseURI = "<BASE URI TO SET>";

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

  // SET contracts addresses to YLProxy contract.
  await ylProxy.setERC1155Market(yl1155Marketplace.address);
  await ylProxy.setYLTAddress(ylt.address);
  await ylProxy.setMarketNFTAddress1(ylNFTMarketplace1.address);
  await ylProxy.setMarketNFTAddress2(ylNFTMarketplace2.address);
  await ylProxy.setYLVault(ylVault.address);
  await ylProxy.setAuctionAddress(auction.address);
  await ylProxy.setNFTAddress(ylNFT.address);

  console.log("\n✅ 10 contracts deployed!!");
}
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
