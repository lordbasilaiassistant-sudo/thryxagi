// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ChildToken — Minimal ERC20 for OBSD-paired launches
/// @notice No owner, no tax, no special logic. Just a clean token that pairs with OBSD.
contract ChildToken is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 supply_,
        address recipient_
    ) ERC20(name_, symbol_) {
        _mint(recipient_, supply_);
    }
}
