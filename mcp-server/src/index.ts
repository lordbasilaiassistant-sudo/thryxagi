#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { ethers } from "ethers";
import { ADDRESSES, RPC_URL, EXPLORER, CHAIN_ID } from "./contracts/addresses.js";
import {
  LAUNCHPAD_ABI,
  PLATFORM_ROUTER_ABI,
  CREATOR_TOKEN_ABI,
  ERC20_ABI,
} from "./contracts/abis.js";

const provider = new ethers.JsonRpcProvider(RPC_URL);
const launchPad = new ethers.Contract(ADDRESSES.LAUNCHPAD, LAUNCHPAD_ABI, provider);
const platformRouter = new ethers.Contract(ADDRESSES.PLATFORM_ROUTER, PLATFORM_ROUTER_ABI, provider);
const obsd = new ethers.Contract(ADDRESSES.OBSD, ERC20_ABI, provider);

const server = new McpServer({
  name: "obsd-launchpad",
  version: "1.0.0",
});

// --- Tool: get_platform_stats ---
server.tool(
  "get_platform_stats",
  "Get OBSD LaunchPad platform statistics — total launches, ETH fees collected, contract addresses",
  {},
  async () => {
    const [totalLaunches, totalETHFees, obsdSupply] = await Promise.all([
      launchPad.totalLaunches(),
      platformRouter.totalETHFees(),
      obsd.totalSupply(),
    ]);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              chain: "Base",
              chainId: CHAIN_ID,
              totalLaunches: Number(totalLaunches),
              totalETHFeesCollected: ethers.formatEther(totalETHFees),
              obsdTotalSupply: ethers.formatEther(obsdSupply),
              contracts: {
                launchPad: ADDRESSES.LAUNCHPAD,
                platformRouter: ADDRESSES.PLATFORM_ROUTER,
                obsd: ADDRESSES.OBSD,
                stakingVault: ADDRESSES.STAKING_VAULT,
                feeAggregator: ADDRESSES.FEE_AGGREGATOR,
                referralRegistry: ADDRESSES.REFERRAL_REGISTRY,
              },
              explorer: EXPLORER,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// --- Tool: list_launches ---
server.tool(
  "list_launches",
  "List tokens launched on the OBSD LaunchPad. Optionally filter by creator address.",
  {
    limit: z.number().optional().default(20).describe("Max results to return (default 20)"),
    creator: z.string().optional().describe("Filter by creator payout address"),
  },
  async ({ limit, creator }) => {
    const total = Number(await launchPad.totalLaunches());

    let indices: number[];
    if (creator) {
      const ids: bigint[] = await launchPad.getCreatorLaunches(creator);
      indices = ids.map(Number).reverse().slice(0, limit);
    } else {
      const start = Math.max(0, total - limit);
      indices = [];
      for (let i = total - 1; i >= start; i--) indices.push(i);
    }

    const launches = await Promise.all(
      indices.map(async (i) => {
        const l = await launchPad.launches(i);
        return {
          id: i,
          token: l[0],
          pool: l[1],
          creator: l[2],
          name: l[3],
          symbol: l[4],
          supply: ethers.formatEther(l[5]),
          obsdSeeded: ethers.formatEther(l[6]),
          timestamp: new Date(Number(l[7]) * 1000).toISOString(),
          explorerUrl: `${EXPLORER}/address/${l[0]}`,
        };
      })
    );

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify({ total, showing: launches.length, launches }, null, 2),
        },
      ],
    };
  }
);

// --- Tool: get_token_info ---
server.tool(
  "get_token_info",
  "Get detailed info about a token deployed on the OBSD LaunchPad — stats, pool, creator, earnings, fees",
  {
    address: z.string().describe("Token contract address"),
  },
  async ({ address }) => {
    const token = new ethers.Contract(address, CREATOR_TOKEN_ABI, provider);

    const [
      name,
      symbol,
      totalSupply,
      creator,
      pool,
      totalBurned,
      totalOBSDToCreator,
      totalOBSDToTreasury,
      pendingFees,
      totalFeeBps,
      burnFeeBps,
    ] = await Promise.all([
      token.name(),
      token.symbol(),
      token.totalSupply(),
      token.creator(),
      token.pool(),
      token.totalBurned(),
      token.totalOBSDToCreator(),
      token.totalOBSDToTreasury(),
      token.pendingFees(),
      token.TOTAL_FEE_BPS(),
      token.BURN_FEE_BPS(),
    ]);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              address,
              name,
              symbol,
              totalSupply: ethers.formatEther(totalSupply),
              creator,
              pool,
              totalBurned: ethers.formatEther(totalBurned),
              totalOBSDToCreator: ethers.formatEther(totalOBSDToCreator),
              totalOBSDToTreasury: ethers.formatEther(totalOBSDToTreasury),
              pendingFees: ethers.formatEther(pendingFees),
              feeBps: { total: Number(totalFeeBps), burn: Number(burnFeeBps) },
              explorerUrl: `${EXPLORER}/address/${address}`,
              poolUrl: `${EXPLORER}/address/${pool}`,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// --- Tool: get_creator_earnings ---
server.tool(
  "get_creator_earnings",
  "Check OBSD earnings for a creator address across all their launched tokens",
  {
    address: z.string().describe("Creator payout address"),
  },
  async ({ address }) => {
    const ids: bigint[] = await launchPad.getCreatorLaunches(address);

    if (ids.length === 0) {
      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify({ creator: address, tokensLaunched: 0, message: "No tokens launched by this address" }),
          },
        ],
      };
    }

    const earnings = await Promise.all(
      ids.map(async (id) => {
        const l = await launchPad.launches(Number(id));
        const tokenAddr = l[0];
        const token = new ethers.Contract(tokenAddr, CREATOR_TOKEN_ABI, provider);
        const [obsdEarned, totalBurned, symbol] = await Promise.all([
          token.totalOBSDToCreator(),
          token.totalBurned(),
          token.symbol(),
        ]);
        return {
          token: tokenAddr,
          symbol,
          obsdEarned: ethers.formatEther(obsdEarned),
          totalBurned: ethers.formatEther(totalBurned),
        };
      })
    );

    const obsdBalance = await obsd.balanceOf(address);
    const totalEarned = earnings.reduce(
      (sum, e) => sum + parseFloat(e.obsdEarned),
      0
    );

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              creator: address,
              tokensLaunched: earnings.length,
              totalOBSDEarned: totalEarned.toFixed(6),
              currentOBSDBalance: ethers.formatEther(obsdBalance),
              tokens: earnings,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// --- Tool: quote_buy ---
server.tool(
  "quote_buy",
  "Get a quote for buying a token with ETH via the PlatformRouter (includes 0.5% ETH fee)",
  {
    token: z.string().describe("Token contract address"),
    eth_amount: z.string().describe("Amount of ETH to spend (e.g. '0.001')"),
  },
  async ({ token, eth_amount }) => {
    const ethWei = ethers.parseEther(eth_amount);
    const tokensOut = await platformRouter.quoteETHToChild(token, ethWei);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              token,
              ethIn: eth_amount,
              tokensOut: ethers.formatEther(tokensOut),
              platformFee: (parseFloat(eth_amount) * 0.005).toFixed(6) + " ETH",
              note: "Quote is an estimate. Actual output depends on slippage.",
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// --- Tool: launch_token ---
server.tool(
  "launch_token",
  "Deploy a new token on the OBSD LaunchPad. Requires DEPLOYER_PRIVATE_KEY env var. The token is paired with OBSD on Aerodrome — the creator earns OBSD on every swap forever.",
  {
    name: z.string().describe("Token name (e.g. 'Degen Ape')"),
    symbol: z.string().describe("Token symbol/ticker (e.g. 'DAPE'), must be unique"),
    payout_address: z.string().describe("Creator wallet that receives OBSD earnings forever"),
    supply: z.string().optional().default("1000000000").describe("Total supply (default 1 billion, 18 decimals applied)"),
    obsd_seed: z.string().optional().default("10000").describe("OBSD to seed the pool (default 10,000)"),
    pool_percent: z.number().optional().default(80).describe("% of supply for pool (default 80, rest is burned)"),
  },
  async ({ name, symbol, payout_address, supply, obsd_seed, pool_percent }) => {
    const privateKey = process.env.DEPLOYER_PRIVATE_KEY;
    if (!privateKey) {
      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify({
              error: "DEPLOYER_PRIVATE_KEY env var not set. Cannot deploy without deployer wallet.",
              hint: "Set DEPLOYER_PRIVATE_KEY in the MCP server env config.",
            }),
          },
        ],
        isError: true,
      };
    }

    // Check if symbol is taken
    const taken = await launchPad.symbolTaken(symbol);
    if (taken) {
      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify({ error: `Symbol "${symbol}" is already taken. Choose a different one.` }),
          },
        ],
        isError: true,
      };
    }

    const wallet = new ethers.Wallet(privateKey, provider);
    const pad = new ethers.Contract(ADDRESSES.LAUNCHPAD, LAUNCHPAD_ABI, wallet);
    const obsdContract = new ethers.Contract(ADDRESSES.OBSD, [
      "function approve(address, uint256) returns (bool)",
    ], wallet);

    const supplyWei = ethers.parseEther(supply);
    const obsdSeedWei = ethers.parseEther(obsd_seed);

    // Approve OBSD for LaunchPad
    const approveTx = await obsdContract.approve(ADDRESSES.LAUNCHPAD, obsdSeedWei);
    await approveTx.wait();

    // Launch
    const tx = await pad.launch(name, symbol, supplyWei, obsdSeedWei, BigInt(pool_percent), payout_address);
    const receipt = await tx.wait();

    // Read the latest launch to get addresses
    const total = await launchPad.totalLaunches();
    const launch = await launchPad.launches(Number(total) - 1);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              success: true,
              token: {
                address: launch[0],
                name,
                symbol,
                supply,
                explorerUrl: `${EXPLORER}/address/${launch[0]}`,
              },
              pool: {
                address: launch[1],
                explorerUrl: `${EXPLORER}/address/${launch[1]}`,
              },
              creator: payout_address,
              obsdSeeded: obsd_seed,
              poolPercent: pool_percent,
              txHash: receipt.hash,
              txUrl: `${EXPLORER}/tx/${receipt.hash}`,
              note: "Token is live! The creator earns OBSD on every swap automatically.",
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// --- Start server ---
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("MCP server error:", err);
  process.exit(1);
});
