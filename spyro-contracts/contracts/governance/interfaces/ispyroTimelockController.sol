// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal Timelock interface for role checks & queueing
interface ISpyroTimelockController {
    function MIN_DELAY() external view returns (uint256);
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32 hash);

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;
}
