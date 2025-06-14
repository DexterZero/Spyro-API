// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../governance/SPYToken.sol";
import "./StakeManager.sol";

contract RewardsDistributor {
    using SafeERC20 for SPYToken;

    uint256 public constant ANNUAL_INFLATION = 3e16;  // 3% (1e18 scale)
    uint256 public constant FEE_BURN_BPS   = 100;     // 1% burn from query fees
    uint256 public immutable genesis;
    SPYToken public immutable token;
    StakeManager public immutable stakeManager;
    uint256 public lastInflationMint;

    event FeesDeposited(address indexed payer, uint256 amountAfterBurn, uint256 burned);
    event InflationMinted(uint256 amount);

    constructor(address _token, address _stakeManager) {
        genesis = block.timestamp;
        token = SPYToken(_token);
        stakeManager = StakeManager(_stakeManager);
    }

    /// anyone can deposit aggregated query fees (e.g., TAP broker)
    function depositFees(uint256 amount) external {
        uint256 burnAmt = (amount * FEE_BURN_BPS) / 10_000;
        token.safeTransferFrom(msg.sender, address(0xdead), burnAmt); // burn address
        token.safeTransferFrom(msg.sender, address(this), amount - burnAmt);
        emit FeesDeposited(msg.sender, amount - burnAmt, burnAmt);
    }

    /// called once per day by keeper / cron
    function mintInflation() external {
        uint256 elapsed = block.timestamp - lastInflationMint;
        require(elapsed >= 1 days, "EARLY");
        uint256 supply = token.totalSupply();
        uint256 annual = (supply * ANNUAL_INFLATION) / 1e18;
        uint256 daily = (annual * elapsed) / 365 days;
        lastInflationMint = block.timestamp;
        token.mint(address(this), daily);
        emit InflationMinted(daily);
    }

    // === TODO: split `token.balanceOf(this)` among active allocations via stakeManager hooks ===
}
