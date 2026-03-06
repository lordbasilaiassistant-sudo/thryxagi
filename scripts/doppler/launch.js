/**
 * Doppler Token Launch — Powered by OBSD / THRYXAGI Platform
 * Launches tokens with OBSD as the numeraire (custom pairing).
 * Every token launched creates OBSD buy pressure.
 * Fees route back to THRYXAGI treasury.
 *
 * DRY RUN by default — set DOPPLER_LIVE=1 to broadcast.
 */

import { createPublicClient, createWalletClient, http, parseEther } from 'viem';
import { base } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';

const OBSD_TOKEN = '0x291AaF4729BaB2528B08d8fE248272b208Ce84FF';
const THRYXAGI_TREASURY = '0x7a3E312Ec6e20a9F62fE2405938EB9060312E334';
const RPC_URL = 'https://mainnet.base.org';

async function main() {
  const sdk = await import('@whetstone-research/doppler-sdk');

  const tokenName = process.env.TOKEN_NAME || 'Doppler Test Token';
  const tokenSymbol = process.env.TOKEN_SYMBOL || 'DTEST';
  const isLive = process.env.DOPPLER_LIVE === '1';

  console.log(`=== DOPPLER LAUNCH${isLive ? '' : ' (DRY RUN)'} — Powered by OBSD ===\n`);

  // Read-only client for simulation
  const publicClient = createPublicClient({
    chain: base,
    transport: http(RPC_URL),
  });

  // Get addresses
  let addresses;
  if (sdk.getAddresses) {
    addresses = sdk.getAddresses(base.id);
    console.log('Factory (Airlock):', addresses.airlock);
    console.log('Token Factory:', addresses.tokenFactory);
    console.log('Pool Manager:', addresses.poolManager);
  }

  // Try building a StaticAuction config with OBSD as numeraire
  console.log('\n--- Building Launch Config ---');
  console.log('Numeraire: OBSD', OBSD_TOKEN);

  if (sdk.StaticAuctionBuilder) {
    try {
      const builder = new sdk.StaticAuctionBuilder();
      const config = builder
        .tokenConfig({
          name: tokenName,
          symbol: tokenSymbol,
          tokenURI: `Powered by OBSD | THRYXAGI Platform | ${tokenSymbol}`,
        })
        .saleConfig({
          initialSupply: parseEther('1000000000'),
          numTokensToSell: parseEther('900000000'),
          numeraire: OBSD_TOKEN,
        })
        .poolByTicks({
          startTick: -92200,
          endTick: -69000,
          fee: 10000,
        })
        .withMigration({ type: 'uniswapV2' })
        .withUserAddress(THRYXAGI_TREASURY)
        .build();

      console.log('\nBuilt config successfully!');
      console.log(JSON.stringify(config, (key, value) =>
        typeof value === 'bigint' ? value.toString() : value
      , 2));
    } catch (e) {
      console.log('StaticAuctionBuilder error:', e.message);
      console.log('This may indicate OBSD numeraire needs different params.');
      console.log('Full error:', e);
    }
  } else {
    console.log('StaticAuctionBuilder not available in SDK exports');
  }

  // Try DynamicAuction as alternative
  if (sdk.DynamicAuctionBuilder) {
    console.log('\n--- Trying DynamicAuctionBuilder ---');
    try {
      const builder = new sdk.DynamicAuctionBuilder();
      console.log('DynamicAuctionBuilder methods:', Object.getOwnPropertyNames(Object.getPrototypeOf(builder)));
    } catch (e) {
      console.log('DynamicAuctionBuilder error:', e.message);
    }
  }

  // Try MulticurveBuilder as alternative
  if (sdk.MulticurveBuilder) {
    console.log('\n--- Trying MulticurveBuilder ---');
    try {
      const builder = new sdk.MulticurveBuilder();
      console.log('MulticurveBuilder methods:', Object.getOwnPropertyNames(Object.getPrototypeOf(builder)));
    } catch (e) {
      console.log('MulticurveBuilder error:', e.message);
    }
  }

  console.log(`\n=== ${isLive ? 'LAUNCH' : 'DRY RUN'} COMPLETE ===`);
  if (!isLive) {
    console.log('Set DOPPLER_LIVE=1 to broadcast. TOKEN_NAME and TOKEN_SYMBOL env vars configure the token.');
  }
}

main().catch(console.error);
