// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// spyro-sdk-js ▸ contracts/staking.ts
// -----------------------------------------------------------------------------
// Strongly-typed helpers for interacting with StakeManager and DelegationPool
// from front-ends or scripts.  Generated ABIs live in src/contracts/abis/.
// -----------------------------------------------------------------------------

import {
  AddressLike,
  ContractRunner,
  ZeroAddress,
  parseUnits,
  parseEther,
} from "ethers";
import { StakeManagerAbi } from "./abis/StakeManager.abi";
import { DelegationPoolAbi } from "./abis/DelegationPool.abi";
import { ethers } from "ethers";

export interface StakingAddresses {
  StakeManager: string;
  DelegationPool: string;
  SPYToken: string;
}

export class StakingContracts {
  readonly stakeManager: ethers.Contract<typeof StakeManagerAbi>;
  readonly delegationPool: ethers.Contract<typeof DelegationPoolAbi>;
  readonly token: ethers.Contract; // generic ERC-20 interface

  constructor(addrs: StakingAddresses, runner: ContractRunner) {
    this.stakeManager = new ethers.Contract(
      addrs.StakeManager,
      StakeManagerAbi,
      runner
    );
    this.delegationPool = new ethers.Contract(
      addrs.DelegationPool,
      DelegationPoolAbi,
      runner
    );
    this.token = new ethers.Contract(
      addrs.SPYToken,
      [
        "function approve(address,uint256) returns (bool)",
        "function allowance(address,address) view returns (uint256)",
        "function balanceOf(address) view returns (uint256)",
        "function decimals() view returns (uint8)",
      ],
      runner
    );
  }

  /* ════════════════════════════════════════════════════════════
     Indexer self-stake helpers
     ═══════════════════════════════════════════════════════════ */

  /** Approve + stake X SPY in a single call (convenience). */
  async stake(amount: string | bigint): Promise<ethers.TransactionResponse> {
    const amt = typeof amount === "string" ? parseEther(amount) : amount;
    const [decimals]: [number] = await this.token.decimals();
    const allowance: bigint = await this.token.allowance(
      await (this.stakeManager.runner?.getAddress() as Promise<string>),
      this.stakeManager.target
    );
    if (allowance < amt) {
      await this.token.approve(this.stakeManager.target, amt);
    }
    return this.stakeManager.stake(amt);
  }

  async queueUnstake(
    amount: string | bigint
  ): Promise<ethers.TransactionResponse> {
    const amt = typeof amount === "string" ? parseEther(amount) : amount;
    return this.stakeManager.queueUnstake(amt);
  }

  async withdraw(): Promise<ethers.TransactionResponse> {
    return this.stakeManager.withdraw();
  }

  /* ════════════════════════════════════════════════════════════
     Delegator helpers
     ═══════════════════════════════════════════════════════════ */

  /** Delegate X SPY to an indexer; auto-approve if allowance missing. */
  async delegate(
    indexer: AddressLike,
    amount: string | bigint
  ): Promise<ethers.TransactionResponse> {
    const amt = typeof amount === "string" ? parseEther(amount) : amount;
    const allowance: bigint = await this.token.allowance(
      await (this.token.runner?.getAddress() as Promise<string>),
      this.delegationPool.target
    );
    if (allowance < amt) {
      await this.token.approve(this.delegationPool.target, amt);
    }
    return this.delegationPool.delegate(indexer, amt);
  }

  async undelegate(
    indexer: AddressLike,
    shares: string | bigint
  ): Promise<ethers.TransactionResponse> {
    const sh = typeof shares === "string" ? parseUnits(shares, 18) : shares;
    return this.delegationPool.queueUndelegate(indexer, sh);
  }

  async claimUndelegated(
    indexer: AddressLike
  ): Promise<ethers.TransactionResponse> {
    return this.delegationPool.claimUndelegated(indexer);
  }

  async claimRewards(
    indexer: AddressLike
  ): Promise<ethers.TransactionResponse> {
    return this.delegationPool.claimRewards(indexer);
  }

  /* ════════════════════════════════════════════════════════════
     Read-only helpers
     ═══════════════════════════════════════════════════════════ */

  async selfStakeOf(indexer: AddressLike): Promise<bigint> {
    return this.stakeManager.selfStakeOf(indexer);
  }

  async delegatedStake(indexer: AddressLike): Promise<bigint> {
    return this.delegationPool.delegatedStake(indexer);
  }

  async delegatorShares(
    indexer: AddressLike,
    delegator: AddressLike
  ): Promise<bigint> {
    return this.delegationPool.delegatorShares(indexer, delegator);
  }
}

/* ───────────────── helper factory ───────────────────────────── */

export function connectStaking(
  addrs: StakingAddresses,
  runner: ContractRunner
): StakingContracts {
  return new StakingContracts(addrs, runner);
}
