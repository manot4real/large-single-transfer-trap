# 🚨 Large Single Transfer Trap

A custom smart contract **trap** built for [Drosera Network](https://drosera.network/) — deployed on the **Hoodi Testnet**. This trap monitors for **large single-token transfers** of a specific ERC-20 token and triggers a response when the amount exceeds a defined threshold.

---

## 🔍 Overview

This trap is designed to **detect and respond** when a large transfer is made from a specific account (`WATCHED_ADDRESS`) using a specific ERC-20 token.

- 📌 **Use Case**: Detect suspicious whale activity (e.g., >0.01 token transfers)
- ⚠️ **Triggered When**: A transfer exceeds the configured threshold within a single check interval
- 🧠 **Strategy**: Compare token balance delta over time using Drosera’s `collect()` function

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

## 🔧 File Structure

```
large-transfer-trap/
├── src/
│   └── LargeSingleTransferTrap.sol       # Main trap logic
├── drosera.toml                          # Drosera trap configuration
├── README.md                             # You're reading this!
├── LICENSE                               # MIT License
└── .gitignore                            # Standard ignores for Forge/Drosera
```
---

## ⚙️ drosera.toml Configuration

The drosera.toml file defines how the Drosera relay will interact with your trap:

```
[traps]

[traps.large_single_transfer]
path = "out/LargeSingleTransferTrap.sol/LargeSingleTransferTrap.json"
response_contract = "0x25E2CeF36020A736CF8a4D2cAdD2EBE3940F4608"
response_function = "respondWithBytes(bytes)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
```

---

## 🚀 Getting Started
**1. Install Foundry (Forge)**
```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```
**2. Build the Contract**
```
forge build
```
**3. Run a Dry Test**
```
drosera dryrun --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com
```
Make sure your trap is properly registered in drosera.toml.

---

