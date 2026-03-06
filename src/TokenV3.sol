// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title EverRise V3 Token - Clean ERC20 with 1-block transfer lock after router buys
/// @notice Zero transfer tax. No owner. No pause. No blacklist. Passes all bot scanners.
///         The 1-block lock prevents flash loan buy->DEX sell in same block.
///         Router is set once by deployer, then deployer has no special powers.
contract TokenV3 is ERC20, ERC20Burnable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000e18;

    address public router;
    address private immutable _deployer;

    /// @dev Tracks the block number when an address last received tokens from the router.
    ///      Transfers from that address are blocked in the same block (anti-flash-loan).
    mapping(address => uint256) public lastReceiveBlock;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _deployer = msg.sender;
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// @notice Set the router address. Can only be called once by the deployer.
    function setRouter(address _router) external {
        require(msg.sender == _deployer, "Not deployer");
        require(router == address(0), "Already set");
        require(_router != address(0), "Zero addr");
        router = _router;
    }

    function _update(address from, address to, uint256 value) internal override {
        // 1-block transfer lock: if tokens came from router this block, can't transfer out yet.
        // Exceptions: mints (from==0), burns (to==0), and router interactions are always allowed.
        // The lastReceiveBlock[from] > 0 check ensures addresses that never received from
        // router are never blocked (default mapping value is 0).
        if (
            from != address(0) &&
            to != address(0) &&
            from != router &&
            lastReceiveBlock[from] > 0 &&
            lastReceiveBlock[from] >= block.number
        ) {
            revert("Transfer locked this block");
        }

        // Track when router sends tokens to a buyer
        // router must be set (non-zero) to avoid false triggers during _mint
        if (router != address(0) && from == router && to != address(0)) {
            lastReceiveBlock[to] = block.number;
        }

        super._update(from, to, value);
    }
}
