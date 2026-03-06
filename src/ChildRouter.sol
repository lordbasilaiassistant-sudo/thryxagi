// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ChildRouter — ETH-in/ETH-out router for OBSD-paired child tokens
/// @notice Users send ETH to buy child tokens, or send child tokens to get ETH back.
///         Under the hood, every trade flows through OBSD on Aerodrome pools.
///
/// Buy flow:  ETH → WETH → Aero(WETH/OBSD) → OBSD → Aero(OBSD/Child) → ChildToken → user
/// Sell flow: ChildToken → Aero(Child/OBSD) → OBSD → Aero(OBSD/WETH) → WETH → ETH → user
///
/// NOTE: We route through Aero's OBSD/WETH pool instead of the OBSD bonding curve router
///       because the OBSD token has a 1-block transfer lock after router buys.
///       Aero pool swaps don't trigger this lock, so multi-hop works in one tx.
///       The OBSD/WETH Aero pool still generates volume that benefits the ecosystem.

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IAeroRouter {
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

contract ChildRouter is ReentrancyGuard {
    address public immutable obsdToken;
    address public immutable weth;
    address public immutable aeroRouter;
    address public immutable aeroFactory;
    address public immutable owner;

    event BuyChild(
        address indexed buyer,
        address indexed childToken,
        uint256 ethIn,
        uint256 childOut
    );

    event SellChild(
        address indexed seller,
        address indexed childToken,
        uint256 childIn,
        uint256 ethOut
    );

    constructor(address _obsdToken, address _weth, address _aeroRouter) {
        obsdToken = _obsdToken;
        weth = _weth;
        aeroRouter = _aeroRouter;
        aeroFactory = IAeroRouter(_aeroRouter).defaultFactory();
        owner = msg.sender;

        // Pre-approve max for Aero router (OBSD + WETH)
        IERC20(_obsdToken).approve(_aeroRouter, type(uint256).max);
        IWETH(_weth).approve(_aeroRouter, type(uint256).max);
    }

    /// @notice Buy a child token with ETH.
    ///         ETH → WETH → Aero(WETH→OBSD) → Aero(OBSD→Child) → user
    /// @param childToken The child token to buy
    /// @param minChildOut Minimum child tokens to receive (slippage protection)
    function buyWithETH(address childToken, uint256 minChildOut) external payable nonReentrant {
        require(msg.value > 0, "No ETH");

        // Step 1: Wrap ETH to WETH
        IWETH(weth).deposit{value: msg.value}();

        // Step 2: Multi-hop swap: WETH → OBSD → ChildToken via Aero
        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](2);
        routes[0] = IAeroRouter.Route({
            from: weth,
            to: obsdToken,
            stable: false,
            factory: aeroFactory
        });
        routes[1] = IAeroRouter.Route({
            from: obsdToken,
            to: childToken,
            stable: false,
            factory: aeroFactory
        });

        uint256[] memory amounts = IAeroRouter(aeroRouter).swapExactTokensForTokens(
            msg.value,
            minChildOut,
            routes,
            msg.sender, // tokens go directly to buyer
            block.timestamp + 300
        );

        emit BuyChild(msg.sender, childToken, msg.value, amounts[amounts.length - 1]);
    }

    /// @notice Sell a child token for ETH.
    ///         ChildToken → Aero(Child→OBSD) → Aero(OBSD→WETH) → unwrap → ETH → user
    /// @param childToken The child token to sell
    /// @param childAmount Amount of child tokens to sell
    /// @param minETHOut Minimum ETH to receive (slippage protection)
    function sellForETH(
        address childToken,
        uint256 childAmount,
        uint256 minETHOut
    ) external nonReentrant {
        require(childAmount > 0, "Zero amount");

        // Step 1: Pull child tokens from seller
        IERC20(childToken).transferFrom(msg.sender, address(this), childAmount);
        IERC20(childToken).approve(aeroRouter, childAmount);

        // Step 2: Multi-hop swap: ChildToken → OBSD → WETH via Aero
        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](2);
        routes[0] = IAeroRouter.Route({
            from: childToken,
            to: obsdToken,
            stable: false,
            factory: aeroFactory
        });
        routes[1] = IAeroRouter.Route({
            from: obsdToken,
            to: weth,
            stable: false,
            factory: aeroFactory
        });

        uint256[] memory amounts = IAeroRouter(aeroRouter).swapExactTokensForTokens(
            childAmount,
            0, // slippage checked on final ETH amount
            routes,
            address(this), // WETH comes here so we can unwrap
            block.timestamp + 300
        );

        uint256 wethReceived = amounts[amounts.length - 1];
        require(wethReceived >= minETHOut, "Slippage");

        // Step 3: Unwrap WETH → ETH and send to seller
        IWETH(weth).withdraw(wethReceived);
        (bool ok,) = msg.sender.call{value: wethReceived}("");
        require(ok, "ETH send failed");

        emit SellChild(msg.sender, childToken, childAmount, wethReceived);
    }

    /// @notice Preview how many child tokens you'd get for X ETH
    function quoteETHToChild(address childToken, uint256 ethAmount) external view returns (uint256) {
        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](2);
        routes[0] = IAeroRouter.Route({ from: weth, to: obsdToken, stable: false, factory: aeroFactory });
        routes[1] = IAeroRouter.Route({ from: obsdToken, to: childToken, stable: false, factory: aeroFactory });
        uint256[] memory amounts = IAeroRouter(aeroRouter).getAmountsOut(ethAmount, routes);
        return amounts[amounts.length - 1];
    }

    /// @notice Preview how much ETH you'd get for X child tokens
    function quoteChildToETH(address childToken, uint256 childAmount) external view returns (uint256) {
        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](2);
        routes[0] = IAeroRouter.Route({ from: childToken, to: obsdToken, stable: false, factory: aeroFactory });
        routes[1] = IAeroRouter.Route({ from: obsdToken, to: weth, stable: false, factory: aeroFactory });
        uint256[] memory amounts = IAeroRouter(aeroRouter).getAmountsOut(childAmount, routes);
        return amounts[amounts.length - 1];
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
