// identical setup to above…
const abi = ['function depositFees(uint256)'];
const rewards = new ethers.Contract(REWARDS_DISTRIBUTOR, abi, wallet);

// Called by your TAP broker once it tallies receipts
export async function depositAggregatedFees(amountWei: string) {
  const tx = await rewards.depositFees(amountWei);
  console.log(`[keeper] Fee deposit tx: ${tx.hash}`);
  await tx.wait();
}
