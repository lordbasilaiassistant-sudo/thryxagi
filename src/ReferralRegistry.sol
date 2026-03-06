// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ReferralRegistry — On-chain referral tracking for the OBSD Creator Economy
/// @notice When a creator launches a token with a referral code, the referrer earns
///         a share of that token's OBSD fees forever.
contract ReferralRegistry {
    address public owner;
    uint256 public referralFeeBps = 500; // 5% of creator's fee share

    struct Referrer {
        address addr;
        bytes32 code;
        uint256 totalReferrals;
    }

    // code => referrer address
    mapping(bytes32 => address) public codeToReferrer;
    // referrer address => code
    mapping(address => bytes32) public referrerToCode;
    // token => referrer address
    mapping(address => address) public tokenReferrer;
    // referrer => list of referred tokens
    mapping(address => address[]) public referredTokens;

    event ReferrerRegistered(address indexed referrer, bytes32 indexed code);
    event ReferralRecorded(address indexed token, address indexed referrer);
    event ReferralFeeUpdated(uint256 oldBps, uint256 newBps);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Register as a referrer with a unique code
    /// @param code A unique bytes32 identifier (e.g., keccak256 of a string)
    function registerReferrer(bytes32 code) external {
        require(code != bytes32(0), "Empty code");
        require(codeToReferrer[code] == address(0), "Code taken");
        require(referrerToCode[msg.sender] == bytes32(0), "Already registered");

        codeToReferrer[code] = msg.sender;
        referrerToCode[msg.sender] = code;

        emit ReferrerRegistered(msg.sender, code);
    }

    /// @notice Record a referral for a token launch. Called by LaunchPad.
    /// @param token The launched token address
    /// @param referrer The referrer's address
    function recordReferral(address token, address referrer) external onlyOwner {
        require(token != address(0), "Zero token");
        require(referrer != address(0), "Zero referrer");
        require(tokenReferrer[token] == address(0), "Already referred");
        require(referrerToCode[referrer] != bytes32(0), "Not a referrer");

        tokenReferrer[token] = referrer;
        referredTokens[referrer].push(token);

        emit ReferralRecorded(token, referrer);
    }

    /// @notice Get the referrer for a token (address(0) if none)
    function getReferrer(address token) external view returns (address) {
        return tokenReferrer[token];
    }

    /// @notice Get all tokens referred by a referrer
    function getReferredTokens(address referrer) external view returns (address[] memory) {
        return referredTokens[referrer];
    }

    /// @notice Get referral count for a referrer
    function getReferralCount(address referrer) external view returns (uint256) {
        return referredTokens[referrer].length;
    }

    /// @notice Update referral fee rate (owner only)
    /// @param newBps New fee in basis points (max 2000 = 20%)
    function setReferralFeeBps(uint256 newBps) external onlyOwner {
        require(newBps <= 2000, "Fee too high");
        uint256 old = referralFeeBps;
        referralFeeBps = newBps;
        emit ReferralFeeUpdated(old, newBps);
    }

    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
