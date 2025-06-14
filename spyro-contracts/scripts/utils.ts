import * as fs from "fs";
import * as path from "path";
import { ethers } from "hardhat";

export function loadEnvVar(name: string): string {
  const val = process.env[name];
  if (!val) throw new Error(`Missing env var ${name}`);
  return val;
}

export async function txWait(label: string, tx: any) {
  console.log(`⛓  ${label}: ${tx.hash}`);
  await tx.wait();
}

export function saveJson(relPath: string, data: any) {
  const p = path.resolve(relPath);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, JSON.stringify(data, null, 2));
  console.log(`💾  Wrote ${p}`);
}
