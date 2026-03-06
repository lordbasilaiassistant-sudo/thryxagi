#!/usr/bin/env node
/**
 * Upload Obsidian token logo + metadata to Pinata IPFS.
 *
 * Requirements:
 *   - PINATA_JWT env var set
 *   - Node.js 18+ (uses native fetch)
 *
 * Usage:
 *   node scripts/upload-to-pinata.js
 *
 * Outputs:
 *   - Logo IPFS CID
 *   - Metadata IPFS CID
 *   - Full IPFS URIs for use in token registration
 */

const fs = require("fs");
const path = require("path");

const PINATA_JWT = process.env.PINATA_JWT;
if (!PINATA_JWT) {
  console.error("ERROR: PINATA_JWT env var not set");
  process.exit(1);
}

const PINATA_API = "https://api.pinata.cloud";

async function uploadFile(filePath, name) {
  const fileData = fs.readFileSync(filePath);
  const blob = new Blob([fileData]);

  const formData = new FormData();
  formData.append("file", blob, name);
  formData.append("pinataMetadata", JSON.stringify({ name }));
  formData.append("pinataOptions", JSON.stringify({ cidVersion: 1 }));

  const res = await fetch(`${PINATA_API}/pinning/pinFileToIPFS`, {
    method: "POST",
    headers: { Authorization: `Bearer ${PINATA_JWT}` },
    body: formData,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Pinata upload failed (${res.status}): ${text}`);
  }

  const data = await res.json();
  return data.IpfsHash;
}

async function uploadJSON(jsonObj, name) {
  const res = await fetch(`${PINATA_API}/pinning/pinJSONToIPFS`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${PINATA_JWT}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      pinataContent: jsonObj,
      pinataMetadata: { name },
      pinataOptions: { cidVersion: 1 },
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Pinata JSON upload failed (${res.status}): ${text}`);
  }

  const data = await res.json();
  return data.IpfsHash;
}

async function main() {
  console.log("=== Obsidian (OBSD) Token Asset Upload ===\n");

  // 1. Upload logo SVG
  const logoPath = path.join(__dirname, "..", "assets", "obsidian-logo.svg");
  if (!fs.existsSync(logoPath)) {
    console.error("ERROR: Logo not found at", logoPath);
    process.exit(1);
  }

  console.log("Uploading logo SVG to IPFS...");
  const logoCID = await uploadFile(logoPath, "obsidian-logo.svg");
  const logoURI = `ipfs://${logoCID}`;
  console.log(`  Logo CID: ${logoCID}`);
  console.log(`  Logo URI: ${logoURI}`);
  console.log(`  Gateway:  https://gateway.pinata.cloud/ipfs/${logoCID}\n`);

  // 2. Create and upload metadata JSON
  const metadata = {
    name: "Obsidian",
    symbol: "OBSD",
    description:
      "Self-appreciating deflationary token on Base. Intrinsic Value (IV) mathematically cannot decrease. One-way bonding curve + treasury-backed IV floor. 2% burn on buy, 3% sell tax (all burned). 1% creator fee. Graduates to Aerodrome + Uniswap V4 through 5-tier system. All LP burned. No owner. No pause. No blacklist. Open source.",
    image: logoURI,
    decimals: 18,
    external_url: "https://github.com/drlor/CustomTokenDeployer",
    properties: {
      category: "deflationary",
      chain: "Base",
      chainId: 8453,
      mechanism: "one-way-bonding-curve",
      graduation: "5-tier-gradient",
      dex_targets: ["Aerodrome", "Uniswap V4"],
      creator_fee: "1%",
      burn_on_buy: "2%",
      sell_tax: "3%",
      max_supply: "1,000,000,000",
      lp_burned: true,
      owner_renounced: true,
      audit_status: "self-audited-open-source",
    },
  };

  console.log("Uploading metadata JSON to IPFS...");
  const metaCID = await uploadJSON(metadata, "obsidian-metadata.json");
  const metaURI = `ipfs://${metaCID}`;
  console.log(`  Metadata CID: ${metaCID}`);
  console.log(`  Metadata URI: ${metaURI}`);
  console.log(`  Gateway:      https://gateway.pinata.cloud/ipfs/${metaCID}\n`);

  // 3. Save results locally
  const results = {
    logo: { cid: logoCID, uri: logoURI, gateway: `https://gateway.pinata.cloud/ipfs/${logoCID}` },
    metadata: { cid: metaCID, uri: metaURI, gateway: `https://gateway.pinata.cloud/ipfs/${metaCID}` },
    uploadedAt: new Date().toISOString(),
  };

  const resultsPath = path.join(__dirname, "..", "assets", "ipfs-results.json");
  fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2));
  console.log(`Results saved to: ${resultsPath}`);
  console.log("\n=== Upload Complete ===");
}

main().catch((err) => {
  console.error("Upload failed:", err.message);
  process.exit(1);
});
