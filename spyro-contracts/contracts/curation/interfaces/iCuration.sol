library BondingCurve {
    /// constant-product x*y=k  (simplified, no precision scaling)
    function mint(
        uint256 deposit,
        uint256 poolBalance,
        uint256 totalShares
    ) internal pure returns (uint256) {
        if (totalShares == 0) return deposit; // init 1:1
        return (deposit * totalShares) / poolBalance;
    }

    function burn(
        uint256 shares,
        uint256 poolBalance,
        uint256 totalShares
    ) internal pure returns (uint256) {
        return (shares * poolBalance) / totalShares;
    }

    function price(uint256 poolBalance, uint256 totalShares)
        internal pure returns (uint256)
    {
        return totalShares == 0 ? 1 ether : (poolBalance * 1 ether) / totalShares;
    }
}
