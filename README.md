# 🚨 Large Single Transfer Trap

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

## 2. Create Trap and Edit drosera.toml

**Create Large Single Transfer Trap file**

```
cd ~
```

```
cd my-drosera-trap
```

```
nano src/LargeSingleTransferTrap.sol
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

```

- Save the file using 
- Ctrl X
- Ctrl Y
- and Enter

**Edit drosera.toml**

```
nano drosera.toml
```

Change the values to match this : 

``` 
[traps]

[traps.large_single_transfer]
path = "out/LargeSingleTransferTrap.sol/LargeSingleTransferTrap.json"
response_contract = "0x25E2CeF36020A736CF8a4D2cAdD2EBE3940F4608"
response_function = "respondWithBytes(bytes)"
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
- Enter the command, when prompted, write ofc and press Enter.

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
│   └── LargeSingleTransferTrap.sol       # Main trap logic
├── drosera.toml                          # Drosera trap configuration
├── README.md                             # You're reading this!
├── LICENSE                               # MIT License
└── .gitignore                            # Standard ignores for Forge/Drosera
```

---

## Links

- **Live Trap**: [Drosera App](https://app.drosera.io)
- **Hoodi Etherscan**: [hoodi.etherscan.io](https://hoodi.etherscan.io)
- **Drosera Network**: [drosera.io](https://drosera.io)
- **Documentation**: [docs.drosera.io](https://docs.drosera.io)

---
- **Author**: TheBaldKid
- **X** : [Follow Me](https://x.com/thebaldkid___)


