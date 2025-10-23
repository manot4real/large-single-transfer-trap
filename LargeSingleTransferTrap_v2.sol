// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "drosera-contracts/interfaces/ITrap.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title LargeSingleTransferTrap_v2
 * @notice Detects large *sustained* token balance drops from a monitored address.
 *         Now includes reorg safety, debounce, and lean sampling.
 */
contract LargeSingleTransferTrap_v2 is ITrap {
    // -----------------------------
    // CONFIGURATION CONSTANTS
    // -----------------------------
    address public constant TOKEN = 0x499b095Ed02f76E56444c242EC43A05F9c2A3ac8;
    address public constant MONITORED = 0x216a54E8bFD7D9bB19fCd5730c072F61E1Af2309;
    uint256 public constant THRESHOLD = 10**16; // 0.01 token (18 decimals)
    uint256 public constant COOLDOWN_BLOCKS = 2; // optional debounce window

    string public constant TRAP_NAME = "LargeSingleTransferTrap_v2";

    constructor() {
        require(TOKEN != address(0), "zero token");
        require(MONITORED != address(0), "zero monitored");
    }

    // -----------------------------
    // DATA COLLECTION
    // -----------------------------
    function collect() external view override returns (bytes memory) {
        // Lean: only return balance + block.number
        uint256 bal = IERC20(TOKEN).balanceOf(MONITORED);
        return abi.encode(bal, block.number);
    }

    // -----------------------------
    // RESPONSE LOGIC
    // -----------------------------
    function shouldRespond(bytes[] calldata data)
        external
        pure
        override
        returns (bool, bytes memory)
    {
        if (data.length < 3) return (false, bytes("need 3 samples for debounce"));

        // Drosera passes newest sample at index 0, older ones next.
        (uint256 latestBal, uint256 latestBlock) = abi.decode(data[0], (uint256, uint256));
        (uint256 prevBal, uint256 prevBlock) = abi.decode(data[1], (uint256, uint256));
        (uint256 oldBal, uint256 oldBlock) = abi.decode(data[2], (uint256, uint256));

        // --- Reorg safety ---
        if (latestBlock <= prevBlock || prevBlock <= oldBlock) {
            return (false, bytes("reorg_or_out_of_order"));
        }
        if ((latestBlock - prevBlock) > 2 || (prevBlock - oldBlock) > 2) {
            return (false, bytes("sampling_gap_detected"));
        }

        // --- Compute deltas ---
        if (prevBal > latestBal) {
            uint256 delta1 = prevBal - latestBal;
            // Edge trigger: require that this drop persisted across previous 2 samples
            if (oldBal > prevBal) {
                uint256 delta2 = oldBal - prevBal;

                // Both drops must exceed threshold for sustained drop
                if (delta1 >= THRESHOLD && delta2 >= THRESHOLD) {
                    bytes memory payload = abi.encode(
                        TOKEN,
                        MONITORED,
                        latestBal,
                        delta1,
                        latestBlock,
                        TRAP_NAME
                    );
                    return (true, payload);
                }
            }
        }

        return (false, bytes(""));
    }
}
