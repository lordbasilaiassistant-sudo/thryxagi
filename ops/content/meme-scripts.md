# THRYXAGI — Meme & Visual Content Scripts
> For use with JS canvas or image generation tools.
> All text is final-ready — copy-paste into image tool.

---

## Meme 1: "The IV Always Rises"
**Format:** Dark background, green upward arrow, white text
**Top text:** "when you sell $OBSD"
**Bottom text:** "the floor goes UP for everyone else"
**Small text:** "It's math. IV_new = IV x (1 + T*r/(C-T))"
**Color scheme:** Black bg, #00ff88 arrow, white text
**Twitter caption:** "Selling $OBSD doesn't hurt holders. It helps them. Every. Single. Time."

---

## Meme 2: "AI vs Human Token Team"
**Format:** Two-panel comparison
**Left panel header:** "Human token team"
**Left panel bullets:**
  - insider presale wallets
  - vesting cliffs
  - "dev sold" rug risk
  - "we are building" tweets
**Right panel header:** "THRYXAGI AI team"
**Right panel bullets:**
  - zero token allocation
  - ETH fees only (no dump vector)
  - 106 automated tests
  - deployed 10 tokens while you read this
**Color scheme:** Left = red tint, Right = green tint
**Twitter caption:** "Not all token teams are equal."

---

## Meme 3: "The Flywheel"
**Format:** Circular diagram on dark background
**Nodes (clockwise):**
  1. Deploy tokens (free)
  2. Volume generates fees
  3. Fees go to treasury
  4. Treasury buys OBSD
  5. OBSD IV rises
  6. Attention grows
  7. [back to 1]
**Center text:** "THRYXAGI"
**Caption:** "The flywheel is live. Every trade compounds."

---

## Meme 4: "Math > Vibes"
**Format:** Simple text image, terminal/monospace font
**Text block:**
```
Project A: "Trust us bro"
Project B: IV_new = IV * (1 + T*r/(C-T))

One of these is a promise.
One is a proof.

$OBSD. Base chain.
```
**Color scheme:** Black bg, green monospace text (terminal aesthetic)
**Twitter caption:** "We don't ask for trust. We give you the equation."

---

## Meme 5: "18 Agents Running"
**Format:** Dark grid showing agent names and roles
**Title:** "THRYXAGI ACTIVE AGENTS"
**Grid entries:**
  - Thryx — COO
  - Blaze — VP Marketing
  - Nova — VP Deployment
  - Ledger — VP Treasury
  - Nexus — VP Expansion
  - Sage — VP Strategy
  - Volt — Twitter Specialist
  - Echo — Thread Specialist
  - Amp — Reply Specialist
  - Forge — Token Deployer
  - Mint — API Deployer
  - Beacon — Browser Deployer
  - Scout — Platform Researcher
  - Shield — Security Auditor
  - Atlas — Analytics
  - [3 more pending...]
**Footer:** "All autonomous. All live. @THRYXAGI"
**Color scheme:** Black bg, cyan text, grid lines

---

## Canvas JS Template (for generating text-based memes programmatically)

```javascript
// Run in browser console or Node with canvas package
// Generates 1200x630 Twitter card image

const { createCanvas } = require('canvas'); // npm install canvas
const fs = require('fs');

function makeMeme(topText, bottomText, filename) {
  const canvas = createCanvas(1200, 630);
  const ctx = canvas.getContext('2d');

  // Background
  ctx.fillStyle = '#0a0a0a';
  ctx.fillRect(0, 0, 1200, 630);

  // Top accent line
  ctx.fillStyle = '#00ff88';
  ctx.fillRect(0, 0, 1200, 4);

  // Top text
  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 52px Arial';
  ctx.textAlign = 'center';
  ctx.fillText(topText, 600, 220);

  // Bottom text
  ctx.fillStyle = '#00ff88';
  ctx.font = 'bold 64px Arial';
  ctx.fillText(bottomText, 600, 380);

  // Footer branding
  ctx.fillStyle = '#666666';
  ctx.font = '28px Arial';
  ctx.fillText('@THRYXAGI', 600, 580);

  // Save
  const buffer = canvas.toBuffer('image/png');
  fs.writeFileSync(filename, buffer);
  console.log('Saved:', filename);
}

// Example usage:
makeMeme('when you sell $OBSD', 'the floor goes UP', 'meme1.png');
makeMeme('Math > Vibes', '$OBSD Base chain', 'meme2.png');
```

---

## Infographic: OBSD Tokenomics Visual

**Title:** "How $OBSD works"
**Section 1 — Buy:**
  Arrow in: ETH
  -> 1% to creator (ETH)
  -> 2% tokens burned
  -> rest: tokens out via bonding curve
  -> spot price goes UP

**Section 2 — Sell:**
  Arrow in: Tokens
  -> all tokens BURNED
  -> ETH out at IV price
  -> 3% sell tax (burns, stays in treasury)
  -> IV goes UP for remaining holders

**Section 3 — The Result:**
  IV = ETH treasury / circulating supply
  Both ETH/token ratio RISES on every trade
  Floor cannot go down. Ever.

**Design notes:** Flow chart style. Dark bg. Green arrows for positive flows. White text.

---

## Tweet Templates for Image Posts

When posting meme images, use these captions:

**For IV-related memes:**
"$OBSD: the token where selling raises the floor for everyone who holds.
Math, not promises.
[image]"

**For comparison memes:**
"Pick your team.
[image]
@THRYXAGI — the only AI-operated token empire on Base."

**For flywheel memes:**
"The machine is running.
Tokens -> fees -> treasury -> OBSD buys -> IV rises -> attention.
Repeat.
@THRYXAGI [image]"
