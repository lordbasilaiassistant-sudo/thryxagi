# THRYXAGI — Workflow Examples
> Proven workflows that WORK. Copy these exactly. No improvising.

## 1. Post a Tweet (Python OAuth 1.0a)

Windows curl does NOT support `--oauth1-user`. Use Python instead.

```bash
python3 -c "
import urllib.request, urllib.parse, hmac, hashlib, base64, time, os, json, uuid

api_key = os.environ['TWITTER_API_KEY']
api_secret = os.environ['TWITTER_API_SECRET']
access_token = os.environ['TWITTER_ACCESS_TOKEN']
access_secret = os.environ['TWITTER_ACCESS_TOKEN_SECRET']

url = 'https://api.twitter.com/2/tweets'
method = 'POST'
tweet_text = 'YOUR TWEET TEXT HERE'

oauth_nonce = uuid.uuid4().hex
oauth_timestamp = str(int(time.time()))

params = {
    'oauth_consumer_key': api_key,
    'oauth_nonce': oauth_nonce,
    'oauth_signature_method': 'HMAC-SHA256',
    'oauth_timestamp': oauth_timestamp,
    'oauth_token': access_token,
    'oauth_version': '1.0'
}

param_string = '&'.join(f'{urllib.parse.quote(k,safe=\"\")}={urllib.parse.quote(v,safe=\"\")}' for k,v in sorted(params.items()))
base_string = f'{method}&{urllib.parse.quote(url,safe=\"\")}&{urllib.parse.quote(param_string,safe=\"\")}'
signing_key = f'{urllib.parse.quote(api_secret,safe=\"\")}&{urllib.parse.quote(access_secret,safe=\"\")}'
signature = base64.b64encode(hmac.new(signing_key.encode(), base_string.encode(), hashlib.sha256).digest()).decode()

auth_header = 'OAuth ' + ', '.join([
    f'oauth_consumer_key=\"{urllib.parse.quote(api_key,safe=\"\")}\"',
    f'oauth_nonce=\"{oauth_nonce}\"',
    f'oauth_signature=\"{urllib.parse.quote(signature,safe=\"\")}\"',
    f'oauth_signature_method=\"HMAC-SHA256\"',
    f'oauth_timestamp=\"{oauth_timestamp}\"',
    f'oauth_token=\"{urllib.parse.quote(access_token,safe=\"\")}\"',
    f'oauth_version=\"1.0\"'
])

body = json.dumps({'text': tweet_text}).encode()
req = urllib.request.Request(url, data=body, headers={
    'Authorization': auth_header,
    'Content-Type': 'application/json'
}, method='POST')

try:
    resp = urllib.request.urlopen(req)
    print(resp.read().decode())
except urllib.error.HTTPError as e:
    print(f'HTTP {e.code}: {e.read().decode()}')
"
```

### To reply to a tweet, change the body to:
```python
body = json.dumps({'text': tweet_text, 'reply': {'in_reply_to_tweet_id': 'TWEET_ID_HERE'}}).encode()
```

### Rate limit: ~2 tweets per short window on free tier. Space them out.

---

## 2. Deploy Token on Bankr (MCP Tool)

```
Step 1: ToolSearch with query "+bankr submit"
Step 2: mcp__plugin_bankr-agent_bankr-agent-api__bankr_agent_submit_prompt
        prompt: "deploy a token called TOKEN_NAME with ticker TICKER on base"
Step 3: Wait 15-30 seconds
Step 4: mcp__plugin_bankr-agent_bankr-agent-api__bankr_agent_get_job_status
        job_id: "JOB_ID_FROM_STEP_2"
Step 5: If status "completed" — record contract address
Step 6: Update ops/deployed-tokens.md with new entry
Step 7: Update ops/wallet-rotation.md deploy count
```

### IMPORTANT:
- Check ops/deployed-tokens.md BEFORE deploying (no duplicate tickers)
- Primary wallet (0x7a3E...E334) has limited deploys per wallet on Bankr
- **Bankr wallet and deployer wallet are SEPARATE wallets**
- **Rotation wallets** can bypass plugin limits — deploy directly with private key
- Check ops/wallet-rotation.md for which wallet to use and current deploy counts
- Rotation wallets are REUSABLE for future tasks — not one-time-use
- Bankr fees must be claimed through Bankr (bankr API key wallet)
- OBSD router fees claimed through deployer private key (THRYXTREASURY_PRIVATE_KEY)
- Job takes 15-80 seconds to complete

### Fee Claiming (TWO separate wallets):
- **Bankr tokens**: claim via bankr_agent_submit_prompt — "claim my fees for TOKEN on base"
  - This uses the Bankr API key wallet (different from deployer)
- **OBSD router**: claim via cast/forge using THRYXTREASURY_PRIVATE_KEY
  - `cast send ROUTER_ADDR "claimFees()" --private-key $THRYXTREASURY_PRIVATE_KEY --rpc-url https://mainnet.base.org`

---

## 3. Deploy Token on pump.fun (Browser)

```
Step 1: ToolSearch with query "select:mcp__claude-in-chrome__tabs_context_mcp"
Step 2: mcp__claude-in-chrome__tabs_context_mcp with createIfEmpty: true
Step 3: mcp__claude-in-chrome__tabs_create_mcp (create new tab)
Step 4: mcp__claude-in-chrome__navigate to https://pump.fun/create
Step 5: mcp__claude-in-chrome__read_page (screenshot to see layout)
Step 6: mcp__claude-in-chrome__form_input to fill name, ticker, description
Step 7: For image — use mcp__claude-in-chrome__javascript_tool:
```

### Image upload (JS Canvas + DataTransfer — NEVER click file picker):
```javascript
const canvas = document.createElement('canvas');
canvas.width = 512; canvas.height = 512;
const ctx = canvas.getContext('2d');
const grad = ctx.createRadialGradient(256,256,50,256,256,300);
grad.addColorStop(0, '#00ff88'); grad.addColorStop(1, '#0a0a1e');
ctx.fillStyle = grad; ctx.fillRect(0,0,512,512);
ctx.fillStyle = '#ffffff'; ctx.font = 'bold 72px Arial'; ctx.textAlign = 'center';
ctx.fillText('TICKER', 256, 250);
ctx.font = '28px Arial'; ctx.fillStyle = '#00ff88';
ctx.fillText('Token Name', 256, 310);
canvas.toBlob(blob => {
  const file = new File([blob], 'token.png', {type:'image/png'});
  const dt = new DataTransfer(); dt.items.add(file);
  const input = document.querySelector('input[type="file"]');
  input.files = dt.files;
  input.dispatchEvent(new Event('change', {bubbles:true}));
}, 'image/png');
'done'
```

```
Step 8: Click "Create coin" button
Step 9: Approve wallet transaction in popup
Step 10: Record contract address from result page
Step 11: Update ops/deployed-tokens.md
```

### CRITICAL: NEVER click file upload buttons. Only JS canvas approach.

---

## 4. Check Wallet Balance (cast)

```bash
export PATH="$PATH:/c/Users/drlor/.foundry/bin"
cast balance 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334 --rpc-url https://mainnet.base.org -e
```

## 5. Check OBSD Router State

```bash
export PATH="$PATH:/c/Users/drlor/.foundry/bin"
# Real ETH in treasury
cast call 0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E "realETH()(uint256)" --rpc-url https://mainnet.base.org
# Current phase (0=BondingCurve, 1=Hybrid, 2=Graduated)
cast call 0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E "phase()(uint8)" --rpc-url https://mainnet.base.org
# Pending creator fees
cast call 0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E "pendingCreatorFees()(uint256)" --rpc-url https://mainnet.base.org
```

## 6. Check Bankr Fees

```
ToolSearch: "+bankr submit"
bankr_agent_submit_prompt: "show claimable fees for all my deployed tokens on base"
Wait + check status
```

---

## Common Mistakes to Avoid
1. **curl --oauth1-user** does NOT work on Windows — use Python script above
2. **cast/forge not in PATH** — always prefix with `export PATH="$PATH:/c/Users/drlor/.foundry/bin"`
3. **Clicking file picker** on pump.fun blocks the browser — use JS canvas only
4. **Duplicate tickers** — ALWAYS read ops/deployed-tokens.md first
5. **Going idle without reporting** — if blocked, say WHY. Don't just go silent.
6. **console.log with too many args** in Forge — keep to 2 args max
