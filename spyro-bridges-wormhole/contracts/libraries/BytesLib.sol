// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BytesLib
/// @notice Library for manipulating byte arrays, used in WormholeReceiver for VAA parsing.
library BytesLib {
    /// @notice Slice a byte array without copying into new memory
    function slice(
        bytes memory data,
        uint256 start,
        uint256 len
    ) internal pure returns (bytes memory) {
        require(data.length >= start + len, "BytesLib: slice out of bounds");
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = data[start + i];
        }
        return result;
    }

    /// @notice Convert 32 bytes starting at offset to bytes32
    function toBytes32(bytes memory data, uint256 offset) internal pure returns (bytes32 result) {
        require(data.length >= offset + 32, "BytesLib: toBytes32 out of bounds");
        assembly {
            result := mload(add(add(data, 0x20), offset))
        }
    }

    /// @notice Parse a uint8 from bytes at offset
    function toUint8(bytes memory data, uint256 offset) internal pure returns (uint8) {
        require(data.length >= offset + 1, "BytesLib: toUint8 out of bounds");
        return uint8(data[offset]);
    }

    /// @notice Parse a uint16 (big endian) from bytes at offset
    function toUint16(bytes memory data, uint256 offset) internal pure returns (uint16 result) {
        require(data.length >= offset + 2, "BytesLib: toUint16 out of bounds");
        result = (uint16(uint8(data[offset])) << 8) |
                 uint16(uint8(data[offset + 1]));
    }

    /// @notice Parse a uint32 (big endian) from bytes at offset
    function toUint32(bytes memory data, uint256 offset) internal pure returns (uint32 result) {
        require(data.length >= offset + 4, "BytesLib: toUint32 out of bounds");
        result = (uint32(uint8(data[offset])) << 24) |
                 (uint32(uint8(data[offset + 1])) << 16) |
                 (uint32(uint8(data[offset + 2])) << 8) |
                  uint32(uint8(data[offset + 3]));
    }

    /// @notice Parse a uint64 (big endian) from bytes at offset
    function toUint64(bytes memory data, uint256 offset) internal pure returns (uint64 result) {
        require(data.length >= offset + 8, "BytesLib: toUint64 out of bounds");
        for (uint256 i = 0; i < 8; i++) {
            result |= uint64(uint8(data[offset + i])) << ((7 - i) * 8);
        }
    }

    /// @notice Parse an Ethereum address (20 bytes) from bytes at offset
    function toAddress(bytes memory data, uint256 offset) internal pure returns (address addr) {
        require(data.length >= offset + 20, "BytesLib: toAddress out of bounds");
        assembly {
            addr := div(mload(add(add(data, 0x20), offset)), 0x1000000000000000000000000)
        }
    }
}
