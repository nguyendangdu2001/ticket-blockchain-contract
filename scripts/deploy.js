// imports
const { ethers, run, network } = require("hardhat");

// async main
async function main() {
  const NFTTicketMarketplaceFactory = await ethers.getContractFactory(
    "NFTTicketMarketplace"
  );
  console.log("Deploying contract...");
  const NFTTicketMarketplace = await NFTTicketMarketplaceFactory.deploy();
  await NFTTicketMarketplace.deployed();
  console.log(`Deployed contract to: ${NFTTicketMarketplace.address}`);
  // what happens when we deploy to our hardhat network?
  if (network.config.chainId === 4 && process.env.ETHERSCAN_API_KEY) {
    console.log("Waiting for block confirmations...");
    await NFTTicketMarketplace.deployTransaction.wait(6);
    await verify(NFTTicketMarketplace.address, []);
  }

  //   const currentValue = await NFTTicketMarketplace.retrieve();
  //   console.log(`Current Value is: ${currentValue}`);

  // Update the current value
  //   const transactionResponse = await NFTTicketMarketplace.store(7);
  //   await transactionResponse.wait(1);
  //   const updatedValue = await NFTTicketMarketplace.retrieve();
  //   console.log(`Updated Value is: ${updatedValue}`);
}

// async function verify(contractAddress, args) {
const verify = async (contractAddress, args) => {
  console.log("Verifying contract...");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
  } catch (e) {
    if (e.message.toLowerCase().includes("already verified")) {
      console.log("Already Verified!");
    } else {
      console.log(e);
    }
  }
};

// main
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
module.exports.tags = ["all"];
