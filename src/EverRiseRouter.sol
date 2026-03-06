// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Aerodrome (Base #1 DEX)
// Source: https://github.com/aerodrome-finance/contracts
// Router: https://basescan.org/address/0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43
interface IAerodromeRouter {
    function addLiquidityETH(
        address token, bool stable, uint256 amountTokenDesired,
        uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function poolFor(address tokenA, address tokenB, bool stable, address _factory) external view returns (address pool);
    function defaultFactory() external view returns (address);
    function weth() external view returns (address);
}

// Uniswap V4 (minimal interfaces)
// PositionManager on Base: 0x7C5f5A4bBd8fD63184577525326123B519429bDc
// Actions: https://github.com/Uniswap/v4-periphery/blob/main/src/libraries/Actions.sol
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

/// @title BasaltRouter — Rising-floor bonding curve with dual DEX graduation
/// @notice One-way curve buy, IV-based sell, 3% sell tax, 2% buy burn, 1% creator fee.
///         At graduation threshold, auto-deploys liquidity: 60% Aerodrome + 40% Uniswap V4.
///         All LP permanently burned to 0xdead.
contract BasaltRouter is ReentrancyGuard {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;
    uint256 public constant CREATOR_FEE_BPS = 100;  // 1%
    uint256 public constant BURN_BPS_ON_BUY = 200;  // 2%
    uint256 public constant SELL_TAX_BPS = 300;      // 3%
    uint256 public constant GRADUATION_ETH = 0.001 ether;
    uint256 public constant MAX_BUY_ETH = 0.005 ether;
    uint256 public constant MIN_BUY_ETH = 0.0001 ether;
    uint256 public constant MIN_CIRCULATING = 1e18;
    uint256 public constant AERO_SPLIT_BPS = 6000;   // 60% Aerodrome

    uint8 private constant V4_MINT_POSITION = 0x02;
    uint8 private constant V4_SETTLE_PAIR = 0x0d;
    uint8 private constant V4_SWEEP = 0x14;
    uint24 private constant V4_FEE = 3000;
    int24 private constant V4_TICK_SPACING = 60;
    int24 private constant V4_TICK_LOWER = -887220;
    int24 private constant V4_TICK_UPPER = 887220;

    uint256 private constant BPS = 10_000;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    IBurnableToken public immutable token;
    address public immutable creator;
    IAerodromeRouter public immutable aeroRouter;
    IV4PositionManager public immutable v4Posm;
    address public immutable permit2;
    uint256 public immutable k;

    uint256 public vETH;
    uint256 public vTOK;
    uint256 public realETH;
    uint256 public circulating;
    bool public graduated;
    address public aeroPool;
    uint256 public v4TokenId;
    mapping(address => uint256) public lastBuyBlock;
    uint256 public totalBurned;
    uint256 public totalVolume;

    event Buy(address indexed buyer, uint256 ethIn, uint256 tokensOut, uint256 burned, uint256 newIV);
    event Sell(address indexed seller, uint256 tokensBurned, uint256 ethOut, uint256 newIV);
    event Graduated(address aeroPool, uint256 aeroETH, uint256 aeroTokens, uint256 v4TokenId, uint256 v4ETH, uint256 v4Tokens);

    constructor(
        address _token, address _creator, address _aeroRouter,
        address _v4Posm, address _permit2, uint256 _initialVirtualETH
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
    }

    function buy(uint256 minTokensOut) external payable nonReentrant {
        require(!graduated, "Graduated");
        uint256 ethIn = msg.value;
        require(ethIn >= MIN_BUY_ETH, "Below min");
        require(ethIn <= MAX_BUY_ETH, "Above max");

        uint256 fee = (ethIn * CREATOR_FEE_BPS) / BPS;
        uint256 net = ethIn - fee;
        uint256 newVETH = vETH + net;
        uint256 newVTOK = k / newVETH;
        uint256 tokensOut = vTOK - newVTOK;
        require(tokensOut > 0, "Zero tokens");

        uint256 burnAmt = (tokensOut * BURN_BPS_ON_BUY) / BPS;
        uint256 userTokens = tokensOut - burnAmt;
        require(userTokens >= minTokensOut, "Slippage");

        vETH = newVETH;
        vTOK = newVTOK;
        realETH += net;
        circulating += userTokens;
        totalBurned += burnAmt;
        totalVolume += ethIn;
        lastBuyBlock[msg.sender] = block.number;

        token.transfer(msg.sender, userTokens);
        if (burnAmt > 0) token.burn(burnAmt);
        _sendETH(creator, fee);

        emit Buy(msg.sender, ethIn, userTokens, burnAmt, iv());

        if (realETH >= GRADUATION_ETH) _graduate();
    }

    function sell(uint256 tokenAmount, uint256 minETHOut) external nonReentrant {
        require(!graduated, "Graduated");
        require(tokenAmount > 0, "Zero amount");
        require(block.number > lastBuyBlock[msg.sender], "Same block");
        require(circulating - tokenAmount >= MIN_CIRCULATING, "Min supply");

        uint256 taxTokens = (tokenAmount * SELL_TAX_BPS) / BPS;
        uint256 netTokens = tokenAmount - taxTokens;
        uint256 currentIV = iv();
        uint256 ethPayout = (netTokens * currentIV) / 1e18;
        uint256 creatorFee = (ethPayout * CREATOR_FEE_BPS) / BPS;
        uint256 userETH = ethPayout - creatorFee;

        require(ethPayout <= realETH, "Low treasury");
        require(userETH >= minETHOut, "Slippage");

        token.burnFrom(msg.sender, tokenAmount);
        realETH -= ethPayout;
        circulating -= tokenAmount;
        totalBurned += tokenAmount;
        totalVolume += ethPayout;

        _sendETH(msg.sender, userETH);
        if (creatorFee > 0) _sendETH(creator, creatorFee);
        emit Sell(msg.sender, tokenAmount, userETH, iv());
    }

    function _graduate() internal {
        graduated = true;
        uint256 totalETH = realETH;
        uint256 totalTokens = token.balanceOf(address(this));
        realETH = 0;

        uint256 aeroETH = (totalETH * AERO_SPLIT_BPS) / BPS;
        uint256 aeroTokens = (totalTokens * AERO_SPLIT_BPS) / BPS;
        uint256 v4ETH = totalETH - aeroETH;
        uint256 v4Tokens = totalTokens - aeroTokens;

        _graduateAerodrome(aeroETH, aeroTokens);
        _graduateV4(v4ETH, v4Tokens);
        emit Graduated(aeroPool, aeroETH, aeroTokens, v4TokenId, v4ETH, v4Tokens);
    }

    function _graduateAerodrome(uint256 ethAmt, uint256 tokAmt) internal {
        token.approve(address(aeroRouter), tokAmt);
        aeroRouter.addLiquidityETH{value: ethAmt}(
            address(token), false, tokAmt, 0, 0, address(this), block.timestamp
        );
        address weth = aeroRouter.weth();
        address factory = aeroRouter.defaultFactory();
        aeroPool = aeroRouter.poolFor(address(token), weth, false, factory);
        uint256 lp = IERC20(aeroPool).balanceOf(address(this));
        IERC20(aeroPool).transfer(DEAD, lp);
    }

    function _graduateV4(uint256 ethAmt, uint256 tokAmt) internal {
        token.approve(permit2, tokAmt);
        IPermit2(permit2).approve(address(token), address(v4Posm), uint160(tokAmt), uint48(block.timestamp + 1));

        PoolKey memory poolKey = PoolKey(address(0), address(token), V4_FEE, V4_TICK_SPACING, address(0));
        uint160 sqrtPriceX96 = _computeSqrtPriceX96(tokAmt, ethAmt);
        uint256 liquidity = (_sqrt(ethAmt * tokAmt) * 95) / 100;
        uint256 tokenId = v4Posm.nextTokenId();

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(IV4PositionManager.initializePool.selector, poolKey, sqrtPriceX96);

        bytes memory actions = abi.encodePacked(V4_MINT_POSITION, V4_SETTLE_PAIR, V4_SWEEP);
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(poolKey, V4_TICK_LOWER, V4_TICK_UPPER, liquidity, uint128(ethAmt), uint128(tokAmt), address(this), bytes(""));
        params[1] = abi.encode(address(0), address(token));
        params[2] = abi.encode(address(0), address(this));
        calls[1] = abi.encodeWithSelector(IV4PositionManager.modifyLiquidities.selector, abi.encode(actions, params), block.timestamp);

        v4Posm.multicall{value: ethAmt}(calls);
        v4TokenId = tokenId;
        v4Posm.transferFrom(address(this), DEAD, tokenId);
    }

    function iv() public view returns (uint256) {
        if (circulating == 0) return 0;
        return (realETH * 1e18) / circulating;
    }

    function spotPrice() public view returns (uint256) {
        if (vTOK == 0) return type(uint256).max;
        return (vETH * 1e18) / vTOK;
    }

    function estimateBuy(uint256 ethIn) external view returns (uint256 tokensOut, uint256 burned) {
        uint256 net = ethIn - (ethIn * CREATOR_FEE_BPS) / BPS;
        uint256 newVTOK = k / (vETH + net);
        uint256 raw = vTOK - newVTOK;
        burned = (raw * BURN_BPS_ON_BUY) / BPS;
        tokensOut = raw - burned;
    }

    function estimateSell(uint256 tokenAmt) external view returns (uint256 ethOut) {
        uint256 net = tokenAmt - (tokenAmt * SELL_TAX_BPS) / BPS;
        uint256 gross = (net * iv()) / 1e18;
        ethOut = gross - (gross * CREATOR_FEE_BPS) / BPS;
    }

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
        while (y < z) { z = y; y = (x / y + y) / 2; }
        return z;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
