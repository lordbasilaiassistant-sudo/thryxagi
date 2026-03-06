/**
 * Doppler SDK Discovery Script
 * Extracts factory/contract addresses for Base mainnet from the SDK.
 * No on-chain transactions — read-only.
 */

import { createPublicClient, http } from 'viem';
import { base } from 'viem/chains';

async function main() {
  // Dynamic import to handle potential CJS/ESM issues
  const sdk = await import('@whetstone-research/doppler-sdk');

  console.log('=== DOPPLER SDK DISCOVERY ===\n');

  // 1. Check supported chains
  console.log('--- Supported Chain IDs ---');
  if (sdk.SUPPORTED_CHAIN_IDS) {
    console.log(sdk.SUPPORTED_CHAIN_IDS);
  } else {
    console.log('SUPPORTED_CHAIN_IDS not exported, trying isSupportedChainId...');
    if (sdk.isSupportedChainId) {
      console.log('Base (8453) supported:', sdk.isSupportedChainId(8453));
      console.log('Ethereum (1) supported:', sdk.isSupportedChainId(1));
    }
  }

  // 2. Extract addresses for Base
  console.log('\n--- Base Mainnet Addresses ---');
  if (sdk.getAddresses) {
    const addresses = sdk.getAddresses(base.id);
    console.log(JSON.stringify(addresses, null, 2));
  } else {
    console.log('getAddresses not found. Listing all SDK exports...');
  }

  // 3. List all SDK exports for reference
  console.log('\n--- All SDK Exports ---');
  const exports = Object.keys(sdk).sort();
  for (const key of exports) {
    const val = sdk[key];
    const type = typeof val;
    if (type === 'function') {
      console.log(`  ${key}: [function]`);
    } else if (type === 'object' && val !== null) {
      console.log(`  ${key}: [object] keys=${Object.keys(val).join(', ')}`);
    } else {
      console.log(`  ${key}: ${typeof val === 'bigint' ? val.toString() + 'n' : JSON.stringify(val)}`);
    }
  }

  // 4. Try initializing the SDK (read-only, no wallet)
  console.log('\n--- SDK Initialization (read-only) ---');
  const publicClient = createPublicClient({
    chain: base,
    transport: http('https://mainnet.base.org'),
  });

  if (sdk.DopplerSDK) {
    try {
      const doppler = new sdk.DopplerSDK({
        publicClient,
        chainId: base.id,
      });
      console.log('DopplerSDK initialized successfully (read-only)');
      console.log('SDK properties:', Object.keys(doppler));
      if (doppler.factory) {
        console.log('Factory properties:', Object.keys(doppler.factory));
      }
    } catch (e) {
      console.log('DopplerSDK init error:', e.message);
    }
  }

  // 5. Try builder classes
  console.log('\n--- Builder Classes Available ---');
  for (const name of ['StaticAuctionBuilder', 'DynamicAuctionBuilder', 'MulticurveBuilder']) {
    console.log(`  ${name}: ${sdk[name] ? 'YES' : 'NO'}`);
  }

  // 6. Try mineTokenAddress if available
  if (sdk.mineTokenAddress) {
    console.log('\n--- mineTokenAddress available ---');
    console.log('This can be used to vanity-mine token addresses');
  }

  console.log('\n=== DISCOVERY COMPLETE ===');
}

main().catch(console.error);
