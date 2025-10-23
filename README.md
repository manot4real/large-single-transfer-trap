# 🚨 Large Single Transfer Trap V2 -updated :)

A custom smart contract **trap** built for [Drosera Network](https://drosera.network/) — deployed on the **Hoodi Testnet**. This trap monitors for **large single-token transfers** of a specific ERC-20 token and triggers a response when the amount exceeds a defined threshold.

---

## 🔍 Overview

**LargeSingleTransferTrap** is a Solidity smart contract designed to monitor large outgoing ERC20 token transfers from a specific address. The contract detects significant drops in the monitored address’s token balance and triggers a response when the drop exceeds a defined threshold.

This trap is useful for detecting potential large token transfers, withdrawals, or suspicious activity on monitored accounts.
 
- 📌 **Use Case**: Detect suspicious whale activity 
- ⚠️ **Triggered When**: A transfer exceeds the configured threshold within a single check interval
- 🧠 **Strategy**: Compare token balance delta over time using Drosera’s `collect()` function

**Note :** In this Trap I used the ERC20 Hoodi Testnet Token - DRO , threshold 0.01 and the address to watch is mine.

---

## 🧾 Contract: `LargeSingleTransferTrap.sol`

### 🛠 Key Parameters:

| Parameter         | Value                                                                 |
|------------------|------------------------------------------------------------------------|
| Token Address     | `0xYourTokenAddressHere`                                               |
| Watched Address   | `0xAddressToWatch`                                                     |
| Threshold         | `0.01` tokens (expressed as `0.01 * 10^18` for 18 decimals)            |
| Trap Name         | `"large_single_transfer"`                                              |

> 💡 The threshold can be adjusted in the contract constant:
> ```solidity
> uint256 public constant THRESHOLD = 1e16; // 0.01 tokens with 18 decimals
> ```

---

# TRAP SETUP

## 1. Update Drosera CLI & Foundry CLI 

**Drosera CLI :**

```
droseraup
```

**Foundry CLI :**

```
curl -L https://foundry.paradigm.xyz | bash
```

```
source /root/.bashrc
```

```
foundryup
```

## 2. Create Trap and Edit `drosera.toml`

**Create Large Single Transfer Trap file**

```
cd ~
```

```
cd my-drosera-trap
```

```
nano src/LargeSingleTransferTrap_v2.sol
```

- Copy and paste this in the file.
- You  can edit the following values 
- `TOKEN =` ERC20 token contract address to monitor.
- `MONITORED =` Address whose token balance is monitored.
- `THRESHOLD =` The minimum drop in token balance to trigger the trap (consider token decimals).

```
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
```

- Save the file using 
- Ctrl X
- Ctrl Y
- and Enter

**Edit `drosera.toml`**

```
nano drosera.toml
```

Change the values to match this : 

``` 
ethereum_rpc = "https://ethereum-hoodi-rpc.publicnode.com"
drosera_rpc = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"


[traps]

[traps.large_single_transfer_v2]
path = "out/LargeSingleTransferTrap_v2.sol/LargeSingleTransferTrap>
response_contract = "0x25E2CeF36020A736CF8a4D2cAdD2EBE3940F4608"
response_function = "respondWithBytes(bytes)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = false
whitelist = ["your_operator_address"]
address = "trap_config_address"
```

- Save the file using
- Ctrl X
- Ctrl Y
- and Enter


## 3. Apply the modifications to the Trap.

**1. Compile your Trap's Contract :**

```
forge clean
```

```
forge build
```

**2. Test the trap before deploying :**

```
drosera dryrun
```
- Enter the command, when prompted, write `ofc` and press `Enter`.

**3. Apply and Deploy the Trap :**

```
DROSERA_PRIVATE_KEY=xxx drosera apply
```

- Replace `xxx` with your EVM wallet privatekey (Ensure it's funded with Hoodi ETH)
Enter the command, when prompted, write `ofc` and press `Enter`.

---

## Restart Operator Nodes

```
cd ~
```

```
cd Drosera-Network
```

```
docker compose down -v
```

```
docker compose up -d
```

```
docker compose restart
```

View the logs, you might get unhealthy logs and some errors at first, just let it run for a while :)

```
docker compose logs -f
```


**And you're done :)**


---

## 🔧 File Structure

```
large-transfer-trap/
├── src/
│   └── LargeSingleTransferTrap_v2.sol       # Main trap logic
├── drosera.toml                             # Drosera trap configuration
├── README.md                                # You're reading this!
├── LICENSE                                  # MIT License
└── .gitignore                               # Standard ignores for Forge/Drosera
```

---

## Links

- **Live Trap**: [Drosera App](https://app.drosera.io)
- **Hoodi Etherscan**: [hoodi.etherscan.io](https://hoodi.etherscan.io)
- **Drosera Network**: [drosera.io](https://drosera.io)
- **Documentation**: [docs.drosera.io](https://docs.drosera.io)

---
- **Author**: TheBaldKid
- **X** : [Follow Me <3](https://x.com/thebaldkid___)
- **Trap Deployed and Active** : [LargeSingleTransferTrap_V2](https://app.drosera.io/trap?trapId=0x277c8491fa436f9916dcd441b044d00a571cf338&chainId=560048)


