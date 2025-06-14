import 'dotenv/config';
import cron from 'node-cron';                // npm i node-cron
import { ethers } from 'ethers';

// -------- env --------
const {
  RPC_URL,
  PRIVATE_KEY,
  REWARDS_DISTRIBUTOR,
} = process.env;
if (!RPC_URL || !PRIVATE_KEY || !REWARDS_DISTRIBUTOR) {
  throw new Error('Missing env vars – see .env.example');
}

// -------- setup --------
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet   = new ethers.Wallet(PRIVATE_KEY, provider);
const abi = ['function lastInflationMint() view returns (uint256)',
             'function mintInflation()'];
const rewards = new ethers.Contract(REWARDS_DISTRIBUTOR, abi, wallet);

// -------- job --------
async function tryMint() {
  const last = await rewards.lastInflationMint();
  const elapsed = Date.now()/1000 - Number(last);
  if (elapsed < 24*60*60) {
    console.log(`[keeper] Still ${24*60*60 - elapsed}s until next mint`);
    return;
  }
  const tx = await rewards.mintInflation();
  console.log(`[keeper] Sent mint tx: ${tx.hash}`);
  await tx.wait();
  console.log('[keeper] Inflation minted ✅');
}

// -------- schedule (UTC 01:30 daily) --------
cron.schedule('30 1 * * *', tryMint);   // */24h
console.log('⏰ Inflation keeper started');
