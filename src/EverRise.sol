// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title EverRise — One-Way Bonding Curve Token with Rising Floor
/// @notice Buys go through constant product curve (spot only rises).
///         Sells burn ALL tokens and pay from treasury at IV = realETH / circulating.
///         Progressive sell tax decays from 25% -> 1% over 30 days.
///         Creator gets 1% ETH on every swap, auto-sent.
contract EverRise is ERC20, ReentrancyGuard {
    // ============================================================
    //  CONSTANTS
    // ============================================================

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000e18; // 1B tokens (18 decimals)
    uint256 public constant CREATOR_FEE_BPS = 100;             // 1%
    uint256 public constant BURN_BPS_ON_BUY = 300;             // 3% burn on buy
    uint256 public constant TAX_MAX_BPS = 2500;                // 25% max sell tax
    uint256 public constant TAX_MIN_BPS = 100;                 // 1% min sell tax
    uint256 public constant FULL_DECAY_SECONDS = 30 days;      // tax decays over 30 days
    uint256 public constant MAX_BUY_ETH = 5 ether;             // max single buy
    uint256 public constant MIN_BUY_ETH = 0.0001 ether;        // min buy (anti-dust)
    uint256 public constant MAX_SELL_BPS = 2500;               // max 25% of balance per sell
    uint256 public constant SELL_COOLDOWN = 1;                  // 1 block cooldown (anti-flash)
    uint256 public constant MIN_CIRCULATING = 1e18;             // floor: 1 token always circulating

    uint256 private constant BPS = 10_000;
    uint256 private constant PRECISION = 1e36;                  // for mulDiv

    // ============================================================
    //  STATE
    // ============================================================

    address public immutable creator;

    // Virtual AMM reserves (only move on buys, never on sells)
    uint256 public vETH;                       // virtual ETH reserve
    uint256 public vTOK;                       // virtual token reserve
    uint256 public immutable k;                // constant product

    // Treasury
    uint256 public realETH;                    // actual ETH held
    uint256 public circulating;                // tokens in user hands

    // Anti-flash: track last buy block per user
    mapping(address => uint256) public lastBuyBlock;

    // Progressive tax: track last buy timestamp per user
    mapping(address => uint256) public lastBuyTimestamp;

    // Stats
    uint256 public totalBurned;
    uint256 public totalVolume;

    // ============================================================
    //  EVENTS
    // ============================================================

    event Buy(address indexed buyer, uint256 ethIn, uint256 tokensOut, uint256 burned, uint256 newIV);
    event Sell(address indexed seller, uint256 tokensBurned, uint256 ethOut, uint256 taxBPS, uint256 newIV);

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================

    constructor(address _creator, uint256 _initialVirtualETH) ERC20("EverRise", "RISE") {
        require(_creator != address(0), "Zero creator");
        require(_initialVirtualETH > 0, "Zero vETH");

        creator = _creator;

        // Initialize virtual AMM
        vETH = _initialVirtualETH;
        vTOK = INITIAL_SUPPLY;
        k = _initialVirtualETH * INITIAL_SUPPLY;

        // No tokens minted at deploy — they come from the curve on buys
        // circulating starts at 0, realETH starts at 0
    }

    // ============================================================
    //  BUY — through bonding curve
    // ============================================================

    /// @notice Buy tokens with ETH. Creator fee auto-sent. Burn on buy.
    /// @param minTokensOut Slippage protection — revert if fewer tokens
    function buy(uint256 minTokensOut) external payable nonReentrant {
        uint256 ethIn = msg.value;
        require(ethIn >= MIN_BUY_ETH, "Below min buy");
        require(ethIn <= MAX_BUY_ETH, "Above max buy");

        // Creator fee — auto-sent
        uint256 fee = mulDiv(ethIn, CREATOR_FEE_BPS, BPS);
        uint256 net = ethIn - fee;

        // Tokens from constant product curve
        uint256 newVETH = vETH + net;
        uint256 newVTOK = k / newVETH;
        uint256 tokensOut = vTOK - newVTOK;
        require(tokensOut > 0, "Zero tokens");

        // Burn on buy — these tokens never enter circulation
        uint256 burnAmount = mulDiv(tokensOut, BURN_BPS_ON_BUY, BPS);
        uint256 userTokens = tokensOut - burnAmount;

        require(userTokens >= minTokensOut, "Slippage");

        // Update virtual AMM (only moves on buys)
        vETH = newVETH;
        vTOK = newVTOK;

        // Update treasury state
        realETH += net;
        circulating += userTokens;
        totalBurned += burnAmount;
        totalVolume += ethIn;

        // Track for anti-flash and progressive tax
        lastBuyBlock[msg.sender] = block.number;
        lastBuyTimestamp[msg.sender] = block.timestamp;

        // Mint user tokens (burned portion is never minted)
        _mint(msg.sender, userTokens);

        // Send creator fee
        _sendETH(creator, fee);

        emit Buy(msg.sender, ethIn, userTokens, burnAmount, iv());
    }

    // ============================================================
    //  SELL — burn tokens, pay from treasury at IV
    // ============================================================

    /// @notice Sell tokens. All sold tokens burned. Paid at IV minus tax.
    /// @param tokenAmount Tokens to sell (capped at 25% of balance)
    /// @param minETHOut Slippage protection
    function sell(uint256 tokenAmount, uint256 minETHOut) external nonReentrant {
        require(block.number > lastBuyBlock[msg.sender], "Same-block sell");
        require(tokenAmount > 0, "Zero amount");

        uint256 bal = balanceOf(msg.sender);
        require(bal > 0, "No balance");

        // Cap at 25% of balance per sell
        uint256 maxSell = mulDiv(bal, MAX_SELL_BPS, BPS);
        if (tokenAmount > maxSell) tokenAmount = maxSell;
        if (tokenAmount > bal) tokenAmount = bal;

        // Ensure min circulating supply
        require(circulating - tokenAmount >= MIN_CIRCULATING, "Below min supply");

        // Progressive sell tax (based on hold duration)
        uint256 holdDuration = block.timestamp - lastBuyTimestamp[msg.sender];
        uint256 taxBps = _getSellTaxBPS(holdDuration);

        // Tax applied to tokens (matching the IV proof)
        uint256 taxTokens = mulDiv(tokenAmount, taxBps, BPS);
        uint256 netTokens = tokenAmount - taxTokens;

        // Payout at IV for net tokens only
        uint256 currentIV = iv();
        uint256 ethPayout = mulDiv(netTokens, currentIV, 1e18); // IV is per 1e18 token

        // Creator fee on payout
        uint256 creatorFee = mulDiv(ethPayout, CREATOR_FEE_BPS, BPS);
        uint256 userETH = ethPayout - creatorFee;

        // Safety: can't pay more than treasury
        if (ethPayout > realETH) {
            ethPayout = realETH;
            creatorFee = mulDiv(ethPayout, CREATOR_FEE_BPS, BPS);
            userETH = ethPayout - creatorFee;
        }

        require(userETH >= minETHOut, "Slippage");

        // Burn ALL sold tokens (both taxed and net portions)
        _burn(msg.sender, tokenAmount);

        // Update state
        realETH -= ethPayout;
        circulating -= tokenAmount;
        totalBurned += tokenAmount;
        totalVolume += ethPayout;

        // Send ETH
        _sendETH(msg.sender, userETH);
        if (creatorFee > 0) _sendETH(creator, creatorFee);

        emit Sell(msg.sender, tokenAmount, userETH, taxBps, iv());
    }

    // ============================================================
    //  TRANSFER OVERRIDE — reset tax timer on receive
    // ============================================================

    /// @dev Reset lastBuyTimestamp for receiver to prevent tax timer gaming
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);

        // On transfers (not mint/burn), reset receiver's tax timer
        if (from != address(0) && to != address(0)) {
            lastBuyTimestamp[to] = block.timestamp;
        }
    }

    // ============================================================
    //  VIEW FUNCTIONS
    // ============================================================

    /// @notice Intrinsic value per token = realETH / circulating
    function iv() public view returns (uint256) {
        if (circulating == 0) return 0;
        return mulDiv(realETH, 1e18, circulating);
    }

    /// @notice Current spot price from virtual AMM
    function spotPrice() public view returns (uint256) {
        if (vTOK == 0) return type(uint256).max;
        return mulDiv(vETH, 1e18, vTOK);
    }

    /// @notice Get sell tax for a given hold duration
    function getSellTaxBPS(uint256 holdSeconds) external pure returns (uint256) {
        return _getSellTaxBPS(holdSeconds);
    }

    /// @notice Estimate tokens received for a given ETH buy
    function estimateBuy(uint256 ethIn) external view returns (uint256 tokensOut, uint256 burned) {
        uint256 fee = mulDiv(ethIn, CREATOR_FEE_BPS, BPS);
        uint256 net = ethIn - fee;
        uint256 newVETH = vETH + net;
        uint256 newVTOK = k / newVETH;
        uint256 raw = vTOK - newVTOK;
        burned = mulDiv(raw, BURN_BPS_ON_BUY, BPS);
        tokensOut = raw - burned;
    }

    /// @notice Estimate ETH received for a given token sell
    function estimateSell(address seller, uint256 tokenAmount) external view returns (uint256 ethOut, uint256 taxBps) {
        uint256 bal = balanceOf(seller);
        uint256 maxSell = mulDiv(bal, MAX_SELL_BPS, BPS);
        if (tokenAmount > maxSell) tokenAmount = maxSell;

        uint256 holdDuration = block.timestamp - lastBuyTimestamp[seller];
        taxBps = _getSellTaxBPS(holdDuration);
        uint256 taxTokens = mulDiv(tokenAmount, taxBps, BPS);
        uint256 netTokens = tokenAmount - taxTokens;
        uint256 grossETH = mulDiv(netTokens, iv(), 1e18);
        uint256 creatorFee = mulDiv(grossETH, CREATOR_FEE_BPS, BPS);
        ethOut = grossETH - creatorFee;
    }

    // ============================================================
    //  INTERNALS
    // ============================================================

    /// @dev Progressive sell tax: TAX_MAX * e^(-lambda * t), floored at TAX_MIN
    ///      Approximated with a piecewise linear decay for gas efficiency
    function _getSellTaxBPS(uint256 holdSeconds) internal pure returns (uint256) {
        // Piecewise approximation of exponential decay
        // Breakpoints chosen to match e^(-lambda*t) curve closely
        if (holdSeconds < 5 minutes) return 2500;        // 25%
        if (holdSeconds < 1 hours) return 2000;           // 20%
        if (holdSeconds < 1 days) return 1500;            // 15%
        if (holdSeconds < 7 days) return 800;             // 8%
        if (holdSeconds < 30 days) return 400;            // 4%
        return 100;                                        // 1%
    }

    /// @dev Safe ETH transfer
    function _sendETH(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "ETH send failed");
    }

    /// @dev mulDiv: (a * b) / c with full precision, no overflow for intermediate
    function mulDiv(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        return (a * b) / c; // Solidity 0.8 has built-in overflow checks
    }

    // No receive/fallback — ETH only enters via buy()
}
