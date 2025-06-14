// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract SpyroTimelockController is TimelockController {
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    )
        TimelockController(minDelay, proposers, executors)
    {}
}
