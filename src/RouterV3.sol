// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// ── External Interfaces ──

interface IAerodromeRouter {
    function addLiquidityETH(
        address token, bool stable, uint256 amountTokenDesired,
        uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function poolFor(address tokenA, address tokenB, bool stable, address _factory) external view returns (address pool);
    function defaultFactory() external view returns (address);
    function weth() external view returns (address);
}

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

interface IV4PositionManager {
    function initializePool(PoolKey calldata key, uint160 sqrtPriceX96) external payable returns (int24);
    function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external payable;
    function nextTokenId() external view returns (uint256);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

interface IBurnableToken is IERC20 {
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

/// @title RouterV3 — Gradient Graduation Router with 5-Tier DEX Deployment
/// @notice One-way bonding curve buy, IV-based sell, 3% sell tax, 2% buy burn, 1% creator fee.
///         Graduates in 5 tiers to Aerodrome + Uniswap V4. All LP burned to 0xdead.
///         Security: pull-pattern fees, try/catch tier execution, residual ETH sweep.
contract RouterV3 is ReentrancyGuard {
    // ── Enums ──
    enum Phase { BondingCurve, Hybrid, Graduated }

    // ── Constants ──
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;
    uint256 public constant CREATOR_FEE_BPS = 100;   // 1%
    uint256 public constant BURN_BPS_ON_BUY = 200;   // 2%
    uint256 public constant SELL_TAX_BPS = 300;       // 3%
    uint256 public constant MIN_BUY_ETH = 0.0001 ether;
    uint256 public constant MIN_CIRCULATING = 1e18;   // 1 token always circulating
    // No MAX_BUY — the bonding curve itself provides exponential slippage protection.
    // A 1 ETH buy gets 65% of supply but pays 207% slippage. The curve IS the anti-whale.

    // Tier thresholds (cumulative realETH)
    // Tier 0 lowered to 0.0005 ETH — triggers on very first meaningful buy (~0.001 ETH)
    // for instant DexScreener indexing. Bots find the token immediately.
    uint256 public constant TIER_0_THRESHOLD = 0.0005 ether;
    uint256 public constant TIER_1_THRESHOLD = 0.005 ether;
    uint256 public constant TIER_2_THRESHOLD = 0.02 ether;
    uint256 public constant TIER_3_THRESHOLD = 0.1 ether;
    uint256 public constant TIER_4_THRESHOLD = 0.5 ether;

    // Tier 0 seed amounts — minimal to create valid pools for indexing
    uint256 public constant SEED_AERO_ETH = 0.0002 ether;
    uint256 public constant SEED_V4_ETH = 0.0001 ether;

    // Tier 1-3: deploy 80% of available ETH above previous tier
    uint256 public constant DEPLOY_BPS = 8000;

    // Aerodrome split for tiers 1-3 (50%) and tier 4 (60%)
    uint256 public constant AERO_SPLIT_MID_BPS = 5000;
    uint256 public constant V4_SPLIT_MID_BPS = 3000;
    // Tier 4: 60% aero, 40% V4
    uint256 public constant AERO_SPLIT_FINAL_BPS = 6000;

    // V4 pool params
    uint8 private constant V4_MINT_POSITION = 0x02;
    uint8 private constant V4_SETTLE_PAIR = 0x0d;
    uint8 private constant V4_SWEEP = 0x14;
    uint24 public constant V4_FEE = 3000;
    int24 public constant V4_TICK_SPACING = 60;
    int24 private constant V4_TICK_LOWER = -887220;
    int24 private constant V4_TICK_UPPER = 887220;

    uint256 private constant BPS = 10_000;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 private constant NUM_TIERS = 5;

    // ── Immutables ──
    IBurnableToken public immutable token;
    address public immutable creator;
    IAerodromeRouter public immutable aeroRouter;
    IV4PositionManager public immutable v4Posm;
    address public immutable permit2;
    uint256 public immutable k; // constant product

    // ── State ──
    Phase public phase;
    uint8 public currentTier;
    uint256 public vETH;
    uint256 public vTOK;
    uint256 public realETH;
    uint256 public circulating;
    uint256 public pendingCreatorFees;
    uint256 public totalBurned;
    uint256 public totalVolume;
    uint256 public totalETHDeployed; // cumulative ETH sent to DEXes across all tiers

    // Tier state
    bool[5] public tierCompleted;
    bool[5] public tierFailed;
    uint256[5] public tierETHDeployed; // ETH sent to DEXes per tier

    // DEX state
    address public aeroPool;
    uint256[] public v4TokenIds;
    bool public v4PoolInitialized;

    // Per-user
    mapping(address => uint256) public lastBuyBlock;

    // ── Events ──
    event Buy(address indexed buyer, uint256 ethIn, uint256 tokensOut, uint256 burned, uint256 newIV);
    event Sell(address indexed seller, uint256 tokensBurned, uint256 ethOut, uint256 newIV);
    event TierCompleted(uint8 indexed tier, uint256 aeroETH, uint256 v4ETH);
    event TierFailed(uint8 indexed tier, string reason);
    event TierRetried(uint8 indexed tier, bool success);
    event PhaseChanged(Phase newPhase);
    event FeesClaimed(address indexed creator, uint256 amount);

    // ── Constructor ──
    constructor(
        address _token,
        address _creator,
        address _aeroRouter,
        address _v4Posm,
        address _permit2,
        uint256 _initialVirtualETH
    ) {
        require(_token != address(0) && _creator != address(0), "Zero address");
        require(_aeroRouter != address(0) && _v4Posm != address(0) && _permit2 != address(0), "Zero address");
        require(_initialVirtualETH > 0, "Zero vETH");

        token = IBurnableToken(_token);
        creator = _creator;
        aeroRouter = IAerodromeRouter(_aeroRouter);
        v4Posm = IV4PositionManager(_v4Posm);
        permit2 = _permit2;
        vETH = _initialVirtualETH;
        vTOK = TOTAL_SUPPLY;
        k = _initialVirtualETH * TOTAL_SUPPLY;
        phase = Phase.BondingCurve;
    }

    // ── Buy ──
    function buy(uint256 minTokensOut) external payable nonReentrant {
        require(phase != Phase.Graduated, "Graduated");
        uint256 ethIn = msg.value;
        require(ethIn >= MIN_BUY_ETH, "Below min");

        uint256 fee = Math.mulDiv(ethIn, CREATOR_FEE_BPS, BPS);
        uint256 net = ethIn - fee;

        uint256 newVETH = vETH + net;
        uint256 newVTOK = k / newVETH;
        uint256 tokensOut = vTOK - newVTOK;
        require(tokensOut > 0, "Zero tokens");

        uint256 burnAmt = Math.mulDiv(tokensOut, BURN_BPS_ON_BUY, BPS);
        uint256 userTokens = tokensOut - burnAmt;
        require(userTokens >= minTokensOut, "Slippage");

        vETH = newVETH;
        vTOK = newVTOK;
        realETH += net;
        circulating += userTokens;
        totalBurned += burnAmt;
        totalVolume += ethIn;
        pendingCreatorFees += fee;
        lastBuyBlock[msg.sender] = block.number;

        token.transfer(msg.sender, userTokens);
        if (burnAmt > 0) token.burn(burnAmt);

        emit Buy(msg.sender, ethIn, userTokens, burnAmt, iv());

        // Check tier progression
        _checkTierProgression();
    }

    // ── Sell (available in all phases — IV floor always holds) ──
    function sell(uint256 tokenAmount, uint256 minETHOut) external nonReentrant {
        require(phase != Phase.Graduated, "Graduated");
        require(tokenAmount > 0, "Zero amount");
        require(block.number > lastBuyBlock[msg.sender], "Same block");
        require(circulating - tokenAmount >= MIN_CIRCULATING, "Min supply");

        uint256 taxTokens = Math.mulDiv(tokenAmount, SELL_TAX_BPS, BPS);
        uint256 netTokens = tokenAmount - taxTokens;
        uint256 currentIV = iv();
        uint256 ethPayout = Math.mulDiv(netTokens, currentIV, 1e18);
        uint256 creatorFee = Math.mulDiv(ethPayout, CREATOR_FEE_BPS, BPS);
        uint256 userETH = ethPayout - creatorFee;

        require(ethPayout <= realETH, "Low treasury");
        require(userETH >= minETHOut, "Slippage");

        token.burnFrom(msg.sender, tokenAmount);
        realETH -= ethPayout;
        circulating -= tokenAmount;
        totalBurned += tokenAmount;
        totalVolume += ethPayout;
        pendingCreatorFees += creatorFee;

        _sendETH(msg.sender, userETH);
        emit Sell(msg.sender, tokenAmount, userETH, iv());
    }

    // ── Claim Fees (Pull Pattern) ──
    function claimFees() external nonReentrant {
        require(msg.sender == creator, "Not creator");
        uint256 amount = pendingCreatorFees;
        require(amount > 0, "No fees");
        pendingCreatorFees = 0;
        _sendETH(creator, amount);
        emit FeesClaimed(creator, amount);
    }

    // ── Manual Tier Trigger ──
    /// @notice Anyone can trigger tier progression if threshold is met.
    ///         Prevents buyers from paying surprise gas for tier execution.
    function graduateTier() external nonReentrant {
        _checkTierProgression();
    }

    // ── Retry Failed Tier ──
    function retryTier(uint8 tier) external nonReentrant {
        require(tier < NUM_TIERS, "Invalid tier");
        require(tierFailed[tier], "Tier not failed");
        tierFailed[tier] = false;
        bool success = _executeTier(tier);
        emit TierRetried(tier, success);
    }

    // ── Sweep Residual ETH (Post-Graduation) ──
    /// @notice Sweep dust ETH after graduation. Only sends ETH above realETH + pendingFees.
    function sweepResidualETH() external {
        require(msg.sender == creator, "Not creator");
        require(phase == Phase.Graduated, "Not graduated");
        uint256 reserved = realETH + pendingCreatorFees;
        uint256 bal = address(this).balance;
        if (bal > reserved) {
            _sendETH(creator, bal - reserved);
        }
    }

    // ── View Functions ──
    function iv() public view returns (uint256) {
        if (circulating == 0) return 0;
        return Math.mulDiv(realETH, 1e18, circulating);
    }

    function spotPrice() public view returns (uint256) {
        if (vTOK == 0) return type(uint256).max;
        return Math.mulDiv(vETH, 1e18, vTOK);
    }

    function estimateBuy(uint256 ethIn) external view returns (uint256 tokensOut, uint256 burned) {
        uint256 net = ethIn - Math.mulDiv(ethIn, CREATOR_FEE_BPS, BPS);
        uint256 newVTOK = k / (vETH + net);
        uint256 raw = vTOK - newVTOK;
        burned = Math.mulDiv(raw, BURN_BPS_ON_BUY, BPS);
        tokensOut = raw - burned;
    }

    function estimateSell(uint256 tokenAmt) external view returns (uint256 ethOut) {
        uint256 net = tokenAmt - Math.mulDiv(tokenAmt, SELL_TAX_BPS, BPS);
        uint256 gross = Math.mulDiv(net, iv(), 1e18);
        ethOut = gross - Math.mulDiv(gross, CREATOR_FEE_BPS, BPS);
    }

    function getTierThreshold(uint8 tier) public pure returns (uint256) {
        if (tier == 0) return TIER_0_THRESHOLD;
        if (tier == 1) return TIER_1_THRESHOLD;
        if (tier == 2) return TIER_2_THRESHOLD;
        if (tier == 3) return TIER_3_THRESHOLD;
        if (tier == 4) return TIER_4_THRESHOLD;
        revert("Invalid tier");
    }

    function getV4TokenIdsLength() external view returns (uint256) {
        return v4TokenIds.length;
    }

    // ── Internal: Tier Progression ──
    function _checkTierProgression() internal {
        while (currentTier < NUM_TIERS) {
            uint256 threshold = getTierThreshold(currentTier);
            // Use realETH + totalETHDeployed as threshold check.
            // This measures total buying pressure (monotonically increasing),
            // not current treasury (which shrinks as tiers deploy).
            // This allows a single whale buy to trigger multiple tiers.
            uint256 cumulativeETH = realETH + totalETHDeployed;
            if (cumulativeETH < threshold) break;
            if (tierCompleted[currentTier]) {
                currentTier++;
                continue;
            }
            if (tierFailed[currentTier]) break; // wait for manual retry

            bool success = _executeTier(currentTier);
            if (!success) break;
            currentTier++;
        }
    }

    function _executeTier(uint8 tier) internal returns (bool) {
        if (tier == 0) {
            return _executeTier0();
        } else if (tier == 4) {
            return _executeTier4();
        } else {
            return _executeTierMid(tier);
        }
    }

    // ── Tier 0: Seed pools, transition to Hybrid ──
    function _executeTier0() internal returns (bool) {
        uint256 seedTotal = SEED_AERO_ETH + SEED_V4_ETH;
        if (realETH < seedTotal) {
            tierFailed[0] = true;
            emit TierFailed(0, "Insufficient ETH for seed");
            return false;
        }

        uint256 currentSpot = spotPrice();
        uint256 aeroTokens = Math.mulDiv(SEED_AERO_ETH, 1e18, currentSpot);
        uint256 v4Tokens = Math.mulDiv(SEED_V4_ETH, 1e18, currentSpot);
        uint256 totalTokensNeeded = aeroTokens + v4Tokens;

        if (token.balanceOf(address(this)) < totalTokensNeeded) {
            tierFailed[0] = true;
            emit TierFailed(0, "Insufficient tokens for seed");
            return false;
        }

        // Try both DEXes — track partial success to avoid ETH accounting leak
        bool aeroOk = _tryAddAerodrome(SEED_AERO_ETH, aeroTokens);
        bool v4Ok = _tryAddV4(SEED_V4_ETH, v4Tokens);

        if (!aeroOk && !v4Ok) {
            tierFailed[0] = true;
            emit TierFailed(0, "Both seed pools failed");
            return false;
        }

        // Account for exactly what was deployed (partial success safe)
        uint256 deployed = 0;
        if (aeroOk) deployed += SEED_AERO_ETH;
        if (v4Ok) deployed += SEED_V4_ETH;

        realETH -= deployed;
        totalETHDeployed += deployed;
        tierETHDeployed[0] = deployed;
        tierCompleted[0] = true;

        // Transition to Hybrid: sells disabled, buys still work through router
        phase = Phase.Hybrid;
        emit PhaseChanged(Phase.Hybrid);
        emit TierCompleted(0, aeroOk ? SEED_AERO_ETH : 0, v4Ok ? SEED_V4_ETH : 0);
        return true;
    }

    // ── Tiers 1-3: Add liquidity to existing pools ──
    function _executeTierMid(uint8 tier) internal returns (bool) {
        // Deploy 80% of current realETH, keeping 20% as reserve
        uint256 deployable = Math.mulDiv(realETH, DEPLOY_BPS, BPS);
        if (deployable == 0) return true; // nothing to deploy, mark as done

        uint256 aeroETH = Math.mulDiv(deployable, AERO_SPLIT_MID_BPS, BPS);
        uint256 v4ETH = Math.mulDiv(deployable, V4_SPLIT_MID_BPS, BPS);

        uint256 currentSpot = spotPrice();
        uint256 aeroTokens = Math.mulDiv(aeroETH, 1e18, currentSpot);
        uint256 v4Tokens = Math.mulDiv(v4ETH, 1e18, currentSpot);
        uint256 totalTokensNeeded = aeroTokens + v4Tokens;

        if (token.balanceOf(address(this)) < totalTokensNeeded) {
            tierFailed[tier] = true;
            emit TierFailed(tier, "Insufficient tokens");
            return false;
        }

        bool aeroOk = _tryAddAerodrome(aeroETH, aeroTokens);
        bool v4Ok = _tryAddV4(v4ETH, v4Tokens);

        if (!aeroOk && !v4Ok) {
            tierFailed[tier] = true;
            emit TierFailed(tier, "Both DEX adds failed");
            return false;
        }

        uint256 deployed = 0;
        if (aeroOk) deployed += aeroETH;
        if (v4Ok) deployed += v4ETH;

        realETH -= deployed;
        totalETHDeployed += deployed;
        tierETHDeployed[tier] = deployed;
        tierCompleted[tier] = true;
        emit TierCompleted(tier, aeroOk ? aeroETH : 0, v4Ok ? v4ETH : 0);
        return true;
    }

    // ── Tier 4: Final graduation — deploy ALL remaining ──
    function _executeTier4() internal returns (bool) {
        uint256 totalETH = realETH;
        uint256 totalTokens = token.balanceOf(address(this));

        // Keep enough for pending fees
        if (totalETH <= pendingCreatorFees) return true;
        totalETH -= pendingCreatorFees;

        if (totalETH == 0 || totalTokens == 0) return true;

        uint256 aeroETH = Math.mulDiv(totalETH, AERO_SPLIT_FINAL_BPS, BPS);
        uint256 v4ETH = totalETH - aeroETH;
        uint256 aeroTokens = Math.mulDiv(totalTokens, AERO_SPLIT_FINAL_BPS, BPS);
        uint256 v4Tokens = totalTokens - aeroTokens;

        bool aeroOk = _tryAddAerodrome(aeroETH, aeroTokens);
        bool v4Ok = _tryAddV4(v4ETH, v4Tokens);

        if (!aeroOk && !v4Ok) {
            tierFailed[4] = true;
            emit TierFailed(4, "Both DEX adds failed");
            return false;
        }

        uint256 deployed = 0;
        if (aeroOk) deployed += aeroETH;
        if (v4Ok) deployed += v4ETH;

        realETH -= deployed;
        totalETHDeployed += deployed;
        tierETHDeployed[4] = deployed;
        tierCompleted[4] = true;

        phase = Phase.Graduated;
        emit PhaseChanged(Phase.Graduated);
        emit TierCompleted(4, aeroOk ? aeroETH : 0, v4Ok ? v4ETH : 0);
        return true;
    }

    // ── DEX Integration: Aerodrome ──
    function _tryAddAerodrome(uint256 ethAmt, uint256 tokAmt) internal returns (bool) {
        if (ethAmt == 0 || tokAmt == 0) return true;

        // Slippage: accept 95% minimum
        uint256 minTokens = (tokAmt * 95) / 100;
        uint256 minETH = (ethAmt * 95) / 100;

        try this._addAerodrome(ethAmt, tokAmt, minTokens, minETH) {
            return true;
        } catch {
            return false;
        }
    }

    /// @dev External so it can be called with try/catch. NOT for public use.
    function _addAerodrome(uint256 ethAmt, uint256 tokAmt, uint256 minTokens, uint256 minETH) external {
        require(msg.sender == address(this), "Internal only");

        token.approve(address(aeroRouter), tokAmt);
        aeroRouter.addLiquidityETH{value: ethAmt}(
            address(token), false, tokAmt, minTokens, minETH, address(this), block.timestamp
        );

        // Set pool address on first call
        if (aeroPool == address(0)) {
            address weth = aeroRouter.weth();
            address factory = aeroRouter.defaultFactory();
            aeroPool = aeroRouter.poolFor(address(token), weth, false, factory);
        }

        // Burn LP
        uint256 lp = IERC20(aeroPool).balanceOf(address(this));
        if (lp > 0) {
            IERC20(aeroPool).transfer(DEAD, lp);
        }
    }

    // ── DEX Integration: Uniswap V4 ──
    function _tryAddV4(uint256 ethAmt, uint256 tokAmt) internal returns (bool) {
        if (ethAmt == 0 || tokAmt == 0) return true;

        try this._addV4(ethAmt, tokAmt) {
            return true;
        } catch {
            return false;
        }
    }

    /// @dev External so it can be called with try/catch. NOT for public use.
    function _addV4(uint256 ethAmt, uint256 tokAmt) external {
        require(msg.sender == address(this), "Internal only");

        // Approve token via Permit2
        token.approve(permit2, tokAmt);
        IPermit2(permit2).approve(address(token), address(v4Posm), uint160(tokAmt), uint48(block.timestamp + 1));

        PoolKey memory poolKey = PoolKey(address(0), address(token), V4_FEE, V4_TICK_SPACING, address(0));

        if (!v4PoolInitialized) {
            // First time: initialize + mint
            uint160 sqrtPriceX96 = _computeSqrtPriceX96(tokAmt, ethAmt);
            uint256 liquidity = (_sqrt(ethAmt * tokAmt) * 95) / 100;
            uint256 tokenId = v4Posm.nextTokenId();

            bytes[] memory calls = new bytes[](2);
            calls[0] = abi.encodeWithSelector(IV4PositionManager.initializePool.selector, poolKey, sqrtPriceX96);

            bytes memory actions = abi.encodePacked(V4_MINT_POSITION, V4_SETTLE_PAIR, V4_SWEEP);
            bytes[] memory params = new bytes[](3);
            params[0] = abi.encode(
                poolKey, V4_TICK_LOWER, V4_TICK_UPPER, liquidity, uint128(ethAmt), uint128(tokAmt), address(this), bytes("")
            );
            params[1] = abi.encode(address(0), address(token));
            params[2] = abi.encode(address(0), address(this));
            calls[1] = abi.encodeWithSelector(
                IV4PositionManager.modifyLiquidities.selector, abi.encode(actions, params), block.timestamp
            );

            v4Posm.multicall{value: ethAmt}(calls);
            v4TokenIds.push(tokenId);
            v4Posm.transferFrom(address(this), DEAD, tokenId);
            v4PoolInitialized = true;
        } else {
            // Subsequent: just mint into existing pool
            uint256 liquidity = (_sqrt(ethAmt * tokAmt) * 95) / 100;
            uint256 tokenId = v4Posm.nextTokenId();

            bytes memory actions = abi.encodePacked(V4_MINT_POSITION, V4_SETTLE_PAIR, V4_SWEEP);
            bytes[] memory params = new bytes[](3);
            params[0] = abi.encode(
                poolKey, V4_TICK_LOWER, V4_TICK_UPPER, liquidity, uint128(ethAmt), uint128(tokAmt), address(this), bytes("")
            );
            params[1] = abi.encode(address(0), address(token));
            params[2] = abi.encode(address(0), address(this));

            v4Posm.modifyLiquidities{value: ethAmt}(abi.encode(actions, params), block.timestamp);
            v4TokenIds.push(tokenId);
            v4Posm.transferFrom(address(this), DEAD, tokenId);
        }

        // Revoke Permit2 approval after mint
        token.approve(permit2, 0);
    }

    // ── Internal Helpers ──
    function _sendETH(address to, uint256 amt) internal {
        if (amt == 0) return;
        (bool ok,) = to.call{value: amt}("");
        require(ok, "ETH failed");
    }

    function _computeSqrtPriceX96(uint256 amt1, uint256 amt0) internal pure returns (uint160) {
        return uint160((_sqrt(amt1) << 96) / _sqrt(amt0));
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = x;
        uint256 y = x / 2 + 1;
        while (y < z) {
            z = y;
            y = (x / y + y) / 2;
        }
        return z;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @dev Only accept ETH from self (tier execution), Aero router, or V4 PositionManager
    receive() external payable {
        require(
            msg.sender == address(this) || msg.sender == address(aeroRouter) || msg.sender == address(v4Posm),
            "No direct ETH"
        );
    }
}
