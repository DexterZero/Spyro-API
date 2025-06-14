// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../governance/SPYToken.sol";
import "./libraries/BondingCurve.sol";

/// @notice AI-Graph ID is a bytes32 hash of aigraph.yaml
type GraphID is bytes32;

contract Curation is Ownable {
    using SafeERC20 for SPYToken;

    /* ============ Events ============ */
    event Signalled(
        GraphID indexed graph,
        address indexed curator,
        uint256 deposited,
        uint256 sharesOut
    );
    event Unsignalled(
        GraphID indexed graph,
        address indexed curator,
        uint256 withdrawn,
        uint256 sharesBurned
    );
    event VersionMigrated(
        GraphID indexed oldGraph,
        GraphID indexed newGraph,
        uint256 sharesMigrated
    );

    /* ============ Constants ============ */
    uint256 public constant CURATION_TAX_BPS = 250;   // 2.5 %
    uint256 public constant MIGRATION_TAX_BPS = 100;  // 1  %

    /* ============ Storage ============ */
    SPYToken public immutable token;

    struct Curve {
        uint256 tokens;   // SPY deposited (after tax)
        uint256 shares;   // total curation shares outstanding
    }
    mapping(GraphID => Curve) public curves;
    mapping(GraphID => mapping(address => uint256)) public sharesOf;

    constructor(address _token) {
        token = SPYToken(_token);
    }

    /* ============ External: Signal ============ */
    function signal(GraphID id, uint256 amount) external returns (uint256 sharesOut) {
        require(amount > 0, "ZERO");
        Curve storage c = curves[id];

        // --- apply 2.5 % tax (burn) ------------
        uint256 tax = (amount * CURATION_TAX_BPS) / 10_000;
        uint256 net = amount - tax;
        token.safeTransferFrom(msg.sender, address(this), net);
        token.safeTransferFrom(msg.sender, address(0xdead), tax);

        // --- bonding-curve math ----------------
        sharesOut = BondingCurve.mint(net, c.tokens, c.shares);
        c.tokens += net;
        c.shares += sharesOut;

        sharesOf[id][msg.sender] += sharesOut;
        emit Signalled(id, msg.sender, amount, sharesOut);
    }

    /* ============ External: Unsignal ============ */
    function unsignal(GraphID id, uint256 sharesIn) external returns (uint256 payout) {
        Curve storage c = curves[id];
        uint256 userShares = sharesOf[id][msg.sender];
        require(sharesIn > 0 && sharesIn <= userShares, "SHARES");

        payout = BondingCurve.burn(sharesIn, c.tokens, c.shares);
        c.tokens -= payout;
        c.shares -= sharesIn;
        sharesOf[id][msg.sender] = userShares - sharesIn;

        token.safeTransfer(msg.sender, payout);
        emit Unsignalled(id, msg.sender, payout, sharesIn);
    }

    /* ============ Owner: Upgrade migration ============ */
    function migrateVersion(
        GraphID oldId,
        GraphID newId,
        uint256 sharesToMigrate
    ) external onlyOwner {
        // governance triggers auto-migration; 1 % migration tax
        Curve storage oldC = curves[oldId];
        Curve storage newC = curves[newId];

        uint256 tokensOut = BondingCurve.burn(
            sharesToMigrate, oldC.tokens, oldC.shares
        );
        uint256 tax = (tokensOut * MIGRATION_TAX_BPS) / 10_000;
        uint256 net = tokensOut - tax;

        // burn migration tax
        token.safeTransfer(address(0xdead), tax);

        // mint shares on new curve
        uint256 sharesMinted = BondingCurve.mint(net, newC.tokens, newC.shares);

        // update curves
        oldC.tokens -= tokensOut;
        oldC.shares -= sharesToMigrate;
        newC.tokens += net;
        newC.shares += sharesMinted;

        emit VersionMigrated(oldId, newId, sharesToMigrate);
    }

    /* ============ Views ============ */
    function pricePerShare(GraphID id) external view returns (uint256) {
        Curve storage c = curves[id];
        return BondingCurve.price(c.tokens, c.shares);
    }
}
