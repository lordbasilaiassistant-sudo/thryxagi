// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Basalt — Deflationary rising-floor token on Base
/// @notice Clean ERC20. Zero transfer tax. Ownership renounced after setup.
///         All bonding curve economics live in a separate Router contract.
contract BasaltToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000e18;

    address public router;
    bool public tradingEnabled;

    constructor() ERC20("Basalt", "BSLT") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function setRouter(address _router) external onlyOwner {
        require(router == address(0), "Already set");
        require(_router != address(0), "Zero addr");
        router = _router;
    }

    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Already live");
        require(router != address(0), "No router");
        tradingEnabled = true;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (!tradingEnabled) {
            require(
                from == address(0) ||
                to == address(0) ||
                from == owner() ||
                from == router ||
                to == router,
                "Not live yet"
            );
        }
        super._update(from, to, value);
    }
}
