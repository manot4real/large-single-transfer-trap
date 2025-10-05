// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "drosera-contracts/interfaces/ITrap.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title LargeSingleTransferTrap
 * @notice Detects large transfers out of a monitored address by comparing balance drops.
 *
 * Parameters to configure before deployment:
 * - TOKEN: The ERC20 token address to monitor.
 * - MONITORED: The address to monitor for large outgoing transfers.
 * - THRESHOLD: The minimum drop in token balance to trigger the trap (0.01 token here).
 */
contract LargeSingleTransferTrap is ITrap {
    address public constant TOKEN = 0x499b095Ed02f76E56444c242EC43A05F9c2A3ac8;
    address public constant MONITORED = 0x216a54E8bFD7D9bB19fCd5730c072F61E1Af2309;
    uint256 public constant THRESHOLD = 10**16; // 0.01 token with 18 decimals

    string public constant trapName = "LargeSingleTransferTrap_v1";

    constructor() {
        require(TOKEN != address(0), "zero token");
        require(MONITORED != address(0), "zero monitored address");
    }

    // Sample the current balance of the monitored address
    function collect() external view returns (bytes memory) {
        uint256 balance = IERC20(TOKEN).balanceOf(MONITORED);
        return abi.encode(balance, TOKEN, MONITORED, trapName);
    }

    /**
     * Check if the balance dropped by at least THRESHOLD between two samples.
     * data is an array of collected samples; compares last two.
     * Returns true if drop >= THRESHOLD with encoded info in payload.
     */
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        if (data.length < 2) return (false, bytes(""));

        (uint256 prevBalance, address token, address monitored, string memory name) = abi.decode(data[data.length - 2], (uint256, address, address, string));
        (uint256 latestBalance, , , ) = abi.decode(data[data.length - 1], (uint256, address, address, string));

        if (prevBalance > latestBalance) {
            uint256 delta = prevBalance - latestBalance;
            if (delta >= THRESHOLD) {
                string memory reason = string(abi.encodePacked("large_transfer_out; threshold=", uint2str(THRESHOLD)));
                bytes memory payload = abi.encode(delta, latestBalance, token, monitored, reason);
                return (true, payload);
            }
        }

        return (false, bytes(""));
    }

    // Helper to convert uint to string
    function uint2str(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        str = string(bstr);
    }
}
