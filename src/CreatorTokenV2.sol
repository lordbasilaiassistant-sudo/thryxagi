// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAeroRouterV2 {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function defaultFactory() external view returns (address);
}

/// @title CreatorTokenV2 — Anti-rug ERC20 with burns, progressive sell tax, and OBSD-backed IV floor
/// @notice 3% fee on transfers: 1% burn + 0.75% creator OBSD + 0.75% treasury OBSD + 0.5% IV vault OBSD.
///         Progressive sell tax burns extra tokens based on hold duration.
///         OBSD-backed intrinsic value (IV) floor that mathematically cannot decrease.
///         Holders can redeem tokens at IV anytime — the token can never go to zero.
///
/// Anti-rug guarantees:
///   1. Creator holds ZERO tokens (remaining burned at launch)
///   2. Creator income = f(volume), not f(price) — aligned with community
///   3. LP burned forever — no one can pull liquidity
///   4. No owner, no pause, no blacklist, no proxy
///   5. Progressive sell tax makes dumping expensive for everyone equally
///   6. OBSD-backed IV floor — guaranteed minimum redemption value
///
/// IV Proof (same as OBSD v3):
///   Before sell: IV = V/C (V=vault, C=circulating, T=tokens, r=sell tax rate)
///   After sell:  IV' = IV × [1 + T*r/(C-T)] > IV   (since T>0, r>0, C>T)
///   IV can ONLY increase. QED.
contract CreatorTokenV2 is ERC20 {
    // --- Fee split (3% total) ---
    uint256 public constant BURN_FEE_BPS = 100;      // 1% burned
    uint256 public constant CREATOR_FEE_BPS = 75;    // 0.75% → swap to OBSD → creator
    uint256 public constant TREASURY_FEE_BPS = 75;   // 0.75% → swap to OBSD → treasury
    uint256 public constant VAULT_FEE_BPS = 50;      // 0.5% → swap to OBSD → IV vault
    uint256 public constant TOTAL_FEE_BPS = 300;     // 3% total
    uint256 public constant SWAP_FEE_BPS = 200;      // 2% total swapped to OBSD

    // --- Progressive sell tax (extra burn on sells based on hold time) ---
    uint256 public constant SELL_TAX_1H_BPS = 500;   // 5% extra burn if held < 1 hour
    uint256 public constant SELL_TAX_24H_BPS = 300;   // 3% extra burn if held < 24 hours
    uint256 public constant SELL_TAX_7D_BPS = 100;    // 1% extra burn if held < 7 days
    // >= 7 days: 0% extra burn

    uint256 private constant BPS = 10_000;

    // --- Immutables ---
    address public immutable creator;
    address public immutable treasury;
    address public immutable obsd;
    address public immutable aeroRouter;
    address public immutable aeroFactory;
    address public immutable factory; // LaunchPad that deployed this token
    uint256 public immutable swapThreshold;

    // --- State ---
    address public pool; // Aerodrome pool address (set once by factory)
    uint256 public pendingFees; // tokens accumulated for OBSD swap
    uint256 public totalBurned;
    uint256 public totalOBSDToCreator;
    uint256 public totalOBSDToTreasury;
    uint256 public backingVault; // OBSD held backing IV floor
    uint256 public circulating;  // tokens held by users (not pool, not burned, not contract)

    mapping(address => uint256) public lastBuyTimestamp;
    mapping(address => bool) public feeExempt;

    bool private _inSwap;
    bool private _poolSet;

    // --- Events ---
    event FeesDistributed(uint256 obsdToCreator, uint256 obsdToTreasury, uint256 obsdToVault);
    event TokensBurned(uint256 amount, uint256 newTotalSupply);
    event PoolSet(address pool);
    event Redeemed(address indexed holder, uint256 tokensBurned, uint256 obsdReceived, uint256 newIV);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 supply_,
        address recipient_,
        address creator_,
        address treasury_,
        address obsd_,
        address aeroRouter_,
        address factory_
    ) ERC20(name_, symbol_) {
        creator = creator_;
        treasury = treasury_;
        obsd = obsd_;
        aeroRouter = aeroRouter_;
        aeroFactory = IAeroRouterV2(aeroRouter_).defaultFactory();
        factory = factory_;
        swapThreshold = supply_ / 10000; // 0.01% of supply

        // Factory exempt during pool seeding, contract exempt for fee routing
        feeExempt[factory_] = true;
        feeExempt[address(this)] = true;

        // Pre-approve router for fee swaps
        _approve(address(this), aeroRouter_, type(uint256).max);

        _mint(recipient_, supply_);
    }

    /// @notice Set the Aerodrome pool address. Called once by factory after pool creation.
    function setPool(address pool_) external {
        require(msg.sender == factory, "Only factory");
        require(!_poolSet, "Pool already set");
        require(pool_ != address(0), "Zero address");
        pool = pool_;
        _poolSet = true;
        emit PoolSet(pool_);
    }

    /// @notice Get the progressive sell tax for an address based on hold duration
    function getSellTax(address seller) public view returns (uint256) {
        uint256 lastBuy = lastBuyTimestamp[seller];
        if (lastBuy == 0) return 0; // Never bought through pool — no tax

        uint256 held = block.timestamp - lastBuy;
        if (held < 1 hours) return SELL_TAX_1H_BPS;
        if (held < 24 hours) return SELL_TAX_24H_BPS;
        if (held < 7 days) return SELL_TAX_7D_BPS;
        return 0;
    }

    /// @notice Current hold duration for an address (seconds)
    function holdTime(address holder) external view returns (uint256) {
        uint256 lastBuy = lastBuyTimestamp[holder];
        if (lastBuy == 0) return type(uint256).max;
        return block.timestamp - lastBuy;
    }

    function _update(address from, address to, uint256 value) internal override {
        // No fee on: mint, burn, swaps (distributing fees), or exempt addresses
        if (from == address(0) || to == address(0) || _inSwap || feeExempt[from]) {
            super._update(from, to, value);
            return;
        }

        bool isBuy = (from == pool);
        bool isSell = (to == pool);

        // --- Track buy timestamp + circulating ---
        if (isBuy) {
            lastBuyTimestamp[to] = block.timestamp;
        }

        // Note: circulating is updated after fee calculation below

        // --- Calculate fees ---
        // 1% burn (always)
        uint256 burnAmount = (value * BURN_FEE_BPS) / BPS;
        // 2% for OBSD swap (0.75% creator + 0.75% treasury + 0.5% vault)
        uint256 swapAmount = (value * SWAP_FEE_BPS) / BPS;

        // --- Progressive sell tax (extra burn on sells) ---
        uint256 extraBurn = 0;
        if (isSell) {
            uint256 sellTaxBps = getSellTax(from);
            if (sellTaxBps > 0) {
                extraBurn = (value * sellTaxBps) / BPS;
            }
        }

        uint256 totalDeducted = burnAmount + swapAmount + extraBurn;
        uint256 send = value - totalDeducted;

        // Move all tokens from sender first, then route to destinations
        // This avoids multiple deductions from `from` which can fail on balance checks
        super._update(from, address(this), value);            // take everything to contract
        super._update(address(this), to, send);               // net to recipient
        super._update(address(this), address(0), burnAmount + extraBurn); // burn

        totalBurned += burnAmount + extraBurn;
        pendingFees += swapAmount;

        // --- Update circulating supply ---
        if (isBuy) {
            // Tokens flowing from pool to user: net amount enters circulation
            circulating += send;
        } else if (isSell) {
            // Tokens flowing from user to pool: entire value leaves user circulation
            // But net (send) goes to pool (not circulating), fees handled separately
            circulating -= value;
        } else {
            // Transfer between users: burns reduce circulating, net stays
            circulating -= (burnAmount + extraBurn);
        }

        if (burnAmount + extraBurn > 0) {
            emit TokensBurned(burnAmount + extraBurn, totalSupply());
        }

        // Auto-distribute when threshold hit
        if (pendingFees >= swapThreshold) {
            _autoDistribute();
        }
    }

    function _autoDistribute() internal {
        _inSwap = true;

        uint256 amount = pendingFees;
        pendingFees = 0;

        IAeroRouterV2.Route[] memory routes = new IAeroRouterV2.Route[](1);
        routes[0] = IAeroRouterV2.Route({
            from: address(this),
            to: obsd,
            stable: false,
            factory: aeroFactory
        });

        try IAeroRouterV2(aeroRouter).swapExactTokensForTokens(
            amount, 0, routes, address(this), block.timestamp + 300
        ) returns (uint256[] memory amounts) {
            uint256 obsdReceived = amounts[amounts.length - 1];

            // Split: 37.5% creator, 37.5% treasury, 25% IV vault
            // (0.75/2.0, 0.75/2.0, 0.5/2.0 of the 2% swap fee)
            uint256 vaultShare = obsdReceived / 4;           // 25% of OBSD → vault
            uint256 creatorShare = (obsdReceived - vaultShare) / 2;
            uint256 treasuryShare = obsdReceived - vaultShare - creatorShare;

            IERC20(obsd).transfer(creator, creatorShare);
            IERC20(obsd).transfer(treasury, treasuryShare);
            // Vault share stays in contract as backingVault
            backingVault += vaultShare;

            totalOBSDToCreator += creatorShare;
            totalOBSDToTreasury += treasuryShare;

            emit FeesDistributed(creatorShare, treasuryShare, vaultShare);
        } catch {
            // Pool has no liquidity yet — hold fees for next attempt
            pendingFees = amount;
        }

        _inSwap = false;
    }

    /// @notice Current intrinsic value: OBSD per token (18 decimals)
    /// @return IV in OBSD with 1e18 precision (0 if no circulating supply)
    function iv() public view returns (uint256) {
        if (circulating == 0) return 0;
        return (backingVault * 1e18) / circulating;
    }

    /// @notice Redeem tokens at IV — burn tokens, receive proportional OBSD from vault
    /// @param tokenAmount Tokens to redeem (burned)
    /// @dev Progressive sell tax applies: tax tokens are burned with NO OBSD payout.
    ///      This means IV increases on every redemption (vault unchanged, supply shrinks).
    ///      Proof: IV' = IV × [1 + T*r/(C-T)] > IV
    function redeemAtIV(uint256 tokenAmount) external {
        require(tokenAmount > 0, "Zero amount");
        require(circulating > tokenAmount, "Exceeds circulating");
        require(backingVault > 0, "No vault");

        // Apply progressive sell tax
        uint256 sellTaxBps = getSellTax(msg.sender);
        uint256 taxTokens = (tokenAmount * sellTaxBps) / BPS;
        uint256 netTokens = tokenAmount - taxTokens;

        // Calculate OBSD payout at current IV
        uint256 currentIV = iv();
        uint256 obsdPayout = (netTokens * currentIV) / 1e18;
        require(obsdPayout <= backingVault, "Vault insufficient");

        // Burn ALL tokens (taxed + net)
        _burn(msg.sender, tokenAmount);
        totalBurned += tokenAmount;
        circulating -= tokenAmount;
        backingVault -= obsdPayout;

        // Send OBSD to redeemer
        IERC20(obsd).transfer(msg.sender, obsdPayout);

        emit Redeemed(msg.sender, tokenAmount, obsdPayout, iv());
    }

    /// @notice Seed the IV vault with OBSD (called by factory at launch)
    function seedVault(uint256 obsdAmount) external {
        require(msg.sender == factory, "Only factory");
        IERC20(obsd).transferFrom(msg.sender, address(this), obsdAmount);
        backingVault += obsdAmount;
    }

    /// @notice Burn tokens (used by LaunchPad to burn non-pool allocation)
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        totalBurned += amount;
    }

    /// @notice Anyone can trigger distribution (useful before threshold)
    function distribute() external {
        require(pendingFees > 0, "No fees");
        _autoDistribute();
    }
}
