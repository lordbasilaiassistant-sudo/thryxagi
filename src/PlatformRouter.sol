// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PlatformRouter — ETH-in/ETH-out with auto platform fee
/// @notice Users send ETH to buy tokens, get ETH back on sell. OBSD routing is invisible.
///         0.5% ETH platform fee auto-sent to treasury on every trade (no claiming).
///
/// Revenue for treasury on every trade:
///   1. 0.5% ETH fee (auto-sent, this contract)
///   2. 50% of OBSD from CreatorToken's 3% transfer fee (auto-sent by token)
///
/// Revenue for creator on every trade:
///   1. 50% of OBSD from CreatorToken's 3% transfer fee (auto-sent by token)

interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IAeroPlatformRouter {
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

    function getAmountsOut(
        uint256 amountIn,
        Route[] calldata routes
    ) external view returns (uint256[] memory amounts);

    function defaultFactory() external view returns (address);
}

contract PlatformRouter is ReentrancyGuard {
    uint256 public constant PLATFORM_FEE_BPS = 50; // 0.5% ETH fee

    address public immutable obsdToken;
    address public immutable weth;
    address public immutable aeroRouter;
    address public immutable aeroFactory;
    address public immutable treasury;
    address public immutable owner;

    uint256 public totalETHFees; // lifetime ETH fees collected

    event BuyChild(address indexed buyer, address indexed childToken, uint256 ethIn, uint256 childOut, uint256 ethFee);
    event SellChild(address indexed seller, address indexed childToken, uint256 childIn, uint256 ethOut, uint256 ethFee);

    constructor(address _obsdToken, address _weth, address _aeroRouter, address _treasury) {
        obsdToken = _obsdToken;
        weth = _weth;
        aeroRouter = _aeroRouter;
        aeroFactory = IAeroPlatformRouter(_aeroRouter).defaultFactory();
        treasury = _treasury;
        owner = msg.sender;

        // Pre-approve max for Aero router
        IERC20(_obsdToken).approve(_aeroRouter, type(uint256).max);
        IWETH9(_weth).approve(_aeroRouter, type(uint256).max);
    }

    /// @notice Buy a child token with ETH. 0.5% ETH fee auto-sent to treasury.
    function buyWithETH(address childToken, uint256 minChildOut) external payable nonReentrant {
        require(msg.value > 0, "No ETH");

        // Auto platform fee in ETH → treasury
        uint256 platformFee = (msg.value * PLATFORM_FEE_BPS) / 10000;
        uint256 swapAmount = msg.value - platformFee;

        // Send ETH fee immediately (autoclaim)
        if (platformFee > 0) {
            (bool feeOk,) = treasury.call{value: platformFee}("");
            require(feeOk, "Fee send failed");
            totalETHFees += platformFee;
        }

        // Wrap remaining ETH
        IWETH9(weth).deposit{value: swapAmount}();

        // Multi-hop: WETH → OBSD → ChildToken via Aero
        IAeroPlatformRouter.Route[] memory routes = new IAeroPlatformRouter.Route[](2);
        routes[0] = IAeroPlatformRouter.Route({
            from: weth,
            to: obsdToken,
            stable: false,
            factory: aeroFactory
        });
        routes[1] = IAeroPlatformRouter.Route({
            from: obsdToken,
            to: childToken,
            stable: false,
            factory: aeroFactory
        });

        uint256[] memory amounts = IAeroPlatformRouter(aeroRouter).swapExactTokensForTokens(
            swapAmount,
            minChildOut,
            routes,
            msg.sender, // tokens go directly to buyer
            block.timestamp + 300
        );

        emit BuyChild(msg.sender, childToken, msg.value, amounts[amounts.length - 1], platformFee);
    }

    /// @notice Sell a child token for ETH. 0.5% ETH fee auto-sent to treasury.
    function sellForETH(
        address childToken,
        uint256 childAmount,
        uint256 minETHOut
    ) external nonReentrant {
        require(childAmount > 0, "Zero amount");

        // Pull child tokens from seller
        IERC20(childToken).transferFrom(msg.sender, address(this), childAmount);
        IERC20(childToken).approve(aeroRouter, childAmount);

        // Multi-hop: ChildToken → OBSD → WETH via Aero
        IAeroPlatformRouter.Route[] memory routes = new IAeroPlatformRouter.Route[](2);
        routes[0] = IAeroPlatformRouter.Route({
            from: childToken,
            to: obsdToken,
            stable: false,
            factory: aeroFactory
        });
        routes[1] = IAeroPlatformRouter.Route({
            from: obsdToken,
            to: weth,
            stable: false,
            factory: aeroFactory
        });

        uint256[] memory amounts = IAeroPlatformRouter(aeroRouter).swapExactTokensForTokens(
            childAmount,
            0, // slippage checked on final ETH amount
            routes,
            address(this),
            block.timestamp + 300
        );

        uint256 wethReceived = amounts[amounts.length - 1];

        // Auto platform fee
        uint256 platformFee = (wethReceived * PLATFORM_FEE_BPS) / 10000;
        uint256 userPayout = wethReceived - platformFee;
        require(userPayout >= minETHOut, "Slippage");

        // Unwrap all WETH
        IWETH9(weth).withdraw(wethReceived);

        // Send ETH fee to treasury (autoclaim)
        if (platformFee > 0) {
            (bool feeOk,) = treasury.call{value: platformFee}("");
            require(feeOk, "Fee send failed");
            totalETHFees += platformFee;
        }

        // Send ETH to seller
        (bool ok,) = msg.sender.call{value: userPayout}("");
        require(ok, "ETH send failed");

        emit SellChild(msg.sender, childToken, childAmount, userPayout, platformFee);
    }

    /// @notice Preview buy (accounts for platform fee)
    function quoteETHToChild(address childToken, uint256 ethAmount) external view returns (uint256) {
        uint256 afterFee = ethAmount - (ethAmount * PLATFORM_FEE_BPS) / 10000;
        IAeroPlatformRouter.Route[] memory routes = new IAeroPlatformRouter.Route[](2);
        routes[0] = IAeroPlatformRouter.Route({ from: weth, to: obsdToken, stable: false, factory: aeroFactory });
        routes[1] = IAeroPlatformRouter.Route({ from: obsdToken, to: childToken, stable: false, factory: aeroFactory });
        uint256[] memory amounts = IAeroPlatformRouter(aeroRouter).getAmountsOut(afterFee, routes);
        return amounts[amounts.length - 1];
    }

    /// @notice Preview sell (accounts for platform fee)
    function quoteChildToETH(address childToken, uint256 childAmount) external view returns (uint256) {
        IAeroPlatformRouter.Route[] memory routes = new IAeroPlatformRouter.Route[](2);
        routes[0] = IAeroPlatformRouter.Route({ from: childToken, to: obsdToken, stable: false, factory: aeroFactory });
        routes[1] = IAeroPlatformRouter.Route({ from: obsdToken, to: weth, stable: false, factory: aeroFactory });
        uint256[] memory amounts = IAeroPlatformRouter(aeroRouter).getAmountsOut(childAmount, routes);
        uint256 grossETH = amounts[amounts.length - 1];
        return grossETH - (grossETH * PLATFORM_FEE_BPS) / 10000;
    }

    /// @notice Recover stuck tokens
    function recover(address _token, uint256 _amount) external {
        require(msg.sender == owner, "Only owner");
        IERC20(_token).transfer(msg.sender, _amount);
    }

    /// @notice Recover stuck ETH
    function recoverETH() external {
        require(msg.sender == owner, "Only owner");
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "Send failed");
    }

    receive() external payable {}
}
