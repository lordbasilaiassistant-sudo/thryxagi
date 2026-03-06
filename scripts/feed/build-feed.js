#!/usr/bin/env node
/**
 * build-feed.js — Reads TokenLaunched events from the LaunchPad contract
 * and outputs state/launches.json for the GitHub Pages frontend.
 *
 * Usage:
 *   LAUNCHPAD_ADDRESS=0x... node scripts/feed/build-feed.js
 *
 * Env vars:
 *   RPC_URL          — Base mainnet RPC (default: https://mainnet.base.org)
 *   LAUNCHPAD_ADDRESS — LaunchPad contract address (required)
 *   FROM_BLOCK       — Start block to scan from (default: 0)
 *   OUTPUT_PATH      — Output file path (default: state/launches.json)
 */

const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

// --- Config ---
const RPC_URL = process.env.RPC_URL || "https://mainnet.base.org";
const LAUNCHPAD_ADDRESS = process.env.LAUNCHPAD_ADDRESS;
const FROM_BLOCK = parseInt(process.env.FROM_BLOCK || "0", 10);
const OUTPUT_PATH = process.env.OUTPUT_PATH || path.resolve(__dirname, "../../state/launches.json");

// --- ABI (only the event we need + token name/symbol helpers) ---
const LAUNCHPAD_ABI = [
  "event TokenLaunched(uint256 indexed launchId, address indexed token, address indexed creator, address pool)"
];

const ERC20_ABI = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function totalSupply() view returns (uint256)"
];

async function main() {
  if (!LAUNCHPAD_ADDRESS) {
    console.error("Error: LAUNCHPAD_ADDRESS env var is required");
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const launchpad = new ethers.Contract(LAUNCHPAD_ADDRESS, LAUNCHPAD_ABI, provider);

  console.log(`Scanning TokenLaunched events from block ${FROM_BLOCK}...`);
  console.log(`LaunchPad: ${LAUNCHPAD_ADDRESS}`);
  console.log(`RPC: ${RPC_URL}`);

  // Fetch all TokenLaunched events
  const filter = launchpad.filters.TokenLaunched();
  const events = await launchpad.queryFilter(filter, FROM_BLOCK, "latest");

  console.log(`Found ${events.length} launches`);

  // Build feed entries with token metadata
  const launches = [];
  for (const event of events) {
    const { launchId, token, creator, pool } = event.args;
    const block = await event.getBlock();

    // Fetch token name/symbol
    let name = "Unknown";
    let symbol = "???";
    let totalSupply = "0";
    try {
      const tokenContract = new ethers.Contract(token, ERC20_ABI, provider);
      [name, symbol, totalSupply] = await Promise.all([
        tokenContract.name(),
        tokenContract.symbol(),
        tokenContract.totalSupply()
      ]);
      totalSupply = ethers.formatEther(totalSupply);
    } catch (err) {
      console.warn(`  Warning: could not read metadata for ${token}: ${err.message}`);
    }

    const entry = {
      launchId: launchId.toString(),
      token,
      creator,
      pool,
      name,
      symbol,
      totalSupply,
      timestamp: block.timestamp,
      date: new Date(block.timestamp * 1000).toISOString(),
      blockNumber: event.blockNumber,
      txHash: event.transactionHash
    };

    launches.push(entry);
    console.log(`  #${entry.launchId}: ${symbol} (${name}) — ${token}`);
  }

  // Sort by launchId ascending
  launches.sort((a, b) => Number(a.launchId) - Number(b.launchId));

  // Write output
  const output = {
    updatedAt: new Date().toISOString(),
    chain: "base",
    chainId: 8453,
    launchpadAddress: LAUNCHPAD_ADDRESS,
    totalLaunches: launches.length,
    launches
  };

  const dir = path.dirname(OUTPUT_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(output, null, 2));
  console.log(`\nWrote ${launches.length} launches to ${OUTPUT_PATH}`);
}

main().catch((err) => {
  console.error("Fatal:", err.message);
  process.exit(1);
});
