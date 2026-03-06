#!/usr/bin/env node
/**
 * Post OBSD (Obsidian) launch announcement on Twitter/X via API v2
 */

const { TwitterApi } = require('twitter-api-v2');

const client = new TwitterApi({
  appKey: process.env.TWITTER_API_KEY,
  appSecret: process.env.TWITTER_API_SECRET,
  accessToken: process.env.TWITTER_ACCESS_TOKEN,
  accessSecret: process.env.TWITTER_ACCESS_TOKEN_SECRET,
});

const rwClient = client.readWrite;

// Tweet thread — main tweet + replies
// Resume from tweet 3 — tweets 1 and 2 already posted
// Parent tweet ID from tweet 2: 2029939847436042549
const RESUME_FROM_TWEET_ID = '2029939847436042549';

const tweets = [
  // Tweet 3: transparency proof (no special chars)
  `No trust required. No promises.

- Fully verified open source on Basescan
- 0 owner functions, contract is immutable
- No mint, no pause, no blacklist
- 106 Foundry tests + 13 Python stress tests (100K+ simulated trades)
- Formal IV proof in contract comments

Contract: 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF`,

  // Tweet 4: graduation path
  `5-tier graduation: as the bonding curve fills, OBSD auto-graduates to real DEX liquidity.

Final tier: 60% Aerodrome + 40% Uniswap V4
All LP permanently burned to 0xdead.

No team wallet. No token allocation. Creator earns only from volume. Aligned forever.`,

  // Tweet 5: CTA
  `This is an experiment in honest tokenomics.

Not financial advice. Not a pump. A math proof deployed on-chain.

If you're curious about DeFi mechanisms that hold up under scrutiny -- check the code, run the tests, read the proof.

$OBSD is live now on Base.`,
];

async function postThread() {
  console.log('Resuming OBSD launch thread from tweet 3...\n');

  let previousTweetId = RESUME_FROM_TWEET_ID;

  for (let i = 0; i < tweets.length; i++) {
    const tweetText = tweets[i];
    console.log(`--- Tweet ${i + 1}/${tweets.length} ---`);
    console.log(tweetText);
    console.log(`Characters: ${tweetText.length}`);
    console.log();

    const params = { text: tweetText };
    if (previousTweetId) {
      params.reply = { in_reply_to_tweet_id: previousTweetId };
    }

    try {
      const result = await rwClient.v2.tweet(params);
      previousTweetId = result.data.id;
      console.log(`Posted! Tweet ID: ${result.data.id}`);
      console.log(`URL: https://twitter.com/i/web/status/${result.data.id}\n`);

      // Brief pause between tweets to avoid rate limits
      if (i < tweets.length - 1) {
        await new Promise(r => setTimeout(r, 1500));
      }
    } catch (err) {
      console.error(`Failed to post tweet ${i + 1}:`, err.message || err);
      if (err.data) {
        console.error('API error detail:', JSON.stringify(err.data, null, 2));
      }
      process.exit(1);
    }
  }

  console.log('Thread posted successfully!');
  console.log(`View thread: https://twitter.com/i/web/status/${tweets[0].id || previousTweetId}`);
}

postThread();
