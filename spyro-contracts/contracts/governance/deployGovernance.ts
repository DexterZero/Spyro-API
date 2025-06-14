import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying from:", deployer.address);

  /* 1. Deploy voting token (ERC20Votes) */
  const Token = await ethers.getContractFactory("SPYToken");
  const token = await Token.deploy();
  await token.deployed();
  console.log("SPYToken:", token.address);

  /* 2. Deploy Timelock */
  const Timelock = await ethers.getContractFactory("SpyroTimelockController");
  const minDelay = 60 * 60;                       // 1 hour
  const timelock = await Timelock.deploy(
    minDelay,
    [],                                           // proposers – filled below
    []                                            // executors – open execution
  );
  await timelock.deployed();
  console.log("Timelock:", timelock.address);

  /* 3. Deploy Governor */
  const Governor = await ethers.getContractFactory("SpyroGovernor");
  const votingDelay = 1;                          // blocks
  const votingPeriod = 46_000;                    // ≈1 week
  const proposalThreshold = ethers.utils.parseEther("100000"); // 100 k SPY
  const governor = await Governor.deploy(
    token.address,
    timelock.address,
    votingDelay,
    votingPeriod,
    proposalThreshold
  );
  await governor.deployed();
  console.log("Governor:", governor.address);

  /* 4. Wire roles & security */
  const proposerRole  = await timelock.PROPOSER_ROLE();
  const executorRole  = await timelock.EXECUTOR_ROLE();
  const adminRole     = await timelock.TIMELOCK_ADMIN_ROLE();

  await timelock.grantRole(proposerRole, governor.address);
  await timelock.grantRole(executorRole, ethers.constants.AddressZero); // anyone
  await timelock.revokeRole(adminRole, deployer.address);

  /* 5. Delegate initial voting power to deployer */
  await token.delegate(deployer.address);

  console.log("✅ Governance stack deployed & wired.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
