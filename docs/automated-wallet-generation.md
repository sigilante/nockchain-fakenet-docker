# Automated Wallet Generation for Docker Nodes

This document explains the architecture and implementation strategy for automatically generating wallets for each node instance from the standard fakenet seed phrase.

## Overview

Instead of manually specifying PKHs for each node, we want to:
1. Use the standard fakenet seed phrase
2. Derive child keys automatically based on a child index
3. Each Docker container gets its own unique PKH

## Standard Fakenet Details

```bash
FAKENET_SEEDPHRASE="farm step rhythm surprise math august panther pulse protect remain anger depend adjust sting enable poet describe stone essay blast click horse hair practice"
FAKENET_PKH_0="9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV"  # Index 0 (master)
```

Each child key is derived using:
```bash
nockchain-wallet derive-child <INDEX>
```

## Architecture Options

### Option A: Entrypoint Script (Recommended)

**How it works:**
1. Add an `entrypoint.sh` script to the Docker image
2. Script runs before `nockchain` starts
3. Script derives the wallet from seed phrase + child index
4. Script extracts the PKH and passes it to `nockchain`

**Pros:**
- ✅ Fully automated - no manual wallet generation
- ✅ Dynamic - each container can have different index
- ✅ Flexible - can derive wallets on-the-fly
- ✅ Scriptable - easy to scale to N nodes

**Cons:**
- ⚠️ Adds startup time (wallet derivation takes a few seconds)
- ⚠️ Requires proper error handling
- ⚠️ Seed phrase must be available in environment

**Implementation:**
```bash
#!/bin/bash
# entrypoint.sh

set -e

# Get child key index from environment (default to 0)
CHILD_INDEX="${CHILD_KEY_INDEX:-0}"

# Derive child key and extract PKH
echo "Deriving wallet for child index $CHILD_INDEX..."
DERIVED_PKH=$(nockchain-wallet derive-child \
  --seed-phrase "$FAKENET_SEEDPHRASE" \
  --index "$CHILD_INDEX" \
  --fakenet | grep "PKH:" | awk '{print $2}')

echo "Derived PKH: $DERIVED_PKH"

# nockchain itself no longer takes --mine/--mining-pkh - start it, then point
# a separate zk-pow-mine process at its private gRPC. See the actual
# implementation in docker/entrypoint.sh.
nockchain \
  --fakenet \
  --bind-public-grpc-addr=0.0.0.0:5555 \
  --bind-private-grpc-port=5554 \
  --no-default-peers \
  --bind /ip4/0.0.0.0/udp/30303/quic-v1 &

exec zk-pow-mine \
  --node-addr http://127.0.0.1:5554 \
  --mining-pkh "$DERIVED_PKH"
```

**Docker Compose:**
```yaml
services:
  nockchain-miner-0:
    environment:
      - CHILD_KEY_INDEX=0
      - FAKENET_SEEDPHRASE=farm step rhythm...

  nockchain-miner-1:
    environment:
      - CHILD_KEY_INDEX=1
      - FAKENET_SEEDPHRASE=farm step rhythm...
```

---

### Option B: Pre-Generated Wallets

**How it works:**
1. Generate wallets externally using a script
2. Store PKHs in `.env` file or docker-compose.yml
3. Pass PKHs directly to containers

**Pros:**
- ✅ Simple - no runtime derivation
- ✅ Fast startup - wallets already exist
- ✅ Easy to debug - PKHs are visible
- ✅ No seed phrase in environment

**Cons:**
- ❌ Manual process - must pre-generate wallets
- ❌ Less flexible - adding nodes requires regeneration
- ❌ Not truly automated

**Implementation:**
```bash
# generate-wallets.sh
#!/bin/bash

SEED="farm step rhythm surprise..."

for i in {0..9}; do
  PKH=$(nockchain-wallet derive-child --seed-phrase "$SEED" --index $i --fakenet | grep PKH | awk '{print $2}')
  echo "MINER_${i}_PKH=$PKH" >> .env
done
```

**Docker Compose:**
```yaml
services:
  nockchain-miner-0:
    environment:
      - MINING_PKH=${MINER_0_PKH}

  nockchain-miner-1:
    environment:
      - MINING_PKH=${MINER_1_PKH}
```

---

### Option C: Init Container Pattern

**How it works:**
1. Create a separate "wallet-generator" container
2. It derives wallets and writes them to a shared volume
3. Main containers read PKHs from the volume

**Pros:**
- ✅ Clean separation of concerns
- ✅ Can generate wallets once for multiple nodes
- ✅ Reusable across services

**Cons:**
- ❌ More complex Docker setup
- ❌ Requires volume management
- ❌ Overkill for simple use cases

---

## Technical Challenges to Address

### 1. **Understanding nockchain-wallet derive-child**

First, we need to understand:
- **Exact command syntax**: Does it take `--seed-phrase` or read from file?
- **Output format**: How is the PKH printed? JSON? Plain text?
- **Error handling**: What happens if derivation fails?

**Need to test:**
```bash
# Test command inside container
docker exec nockchain-fakenet-miner nockchain-wallet --help
docker exec nockchain-fakenet-miner nockchain-wallet derive-child --help
```

### 2. **Parsing PKH from Output**

The wallet tool might output:
```
Deriving child key at index 1...
Address: 0x...
PKH: 9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV
Public Key: ...
```

We need robust parsing:
```bash
# Option 1: grep + awk
PKH=$(command | grep "PKH:" | awk '{print $2}')

# Option 2: jq (if JSON output)
PKH=$(command | jq -r '.pkh')

# Option 3: sed
PKH=$(command | sed -n 's/PKH: \(.*\)/\1/p')
```

### 3. **Seed Phrase Security**

Even for fakenet, we should handle the seed phrase properly:

**Bad (hardcoded in Dockerfile):**
```dockerfile
ENV FAKENET_SEEDPHRASE="farm step..."
```

**Good (passed at runtime):**
```yaml
# docker-compose.yml
environment:
  - FAKENET_SEEDPHRASE=${FAKENET_SEEDPHRASE}
```

**Better (use Docker secrets for production):**
```yaml
secrets:
  - fakenet_seedphrase
```

### 4. **Startup Coordination**

When deriving wallets at runtime:
- **Wallet derivation takes time** - add health checks
- **Nodes start in sequence** - ensure miner starts first
- **Error propagation** - if derivation fails, container should exit clearly

### 5. **Non-Mining Nodes**

For non-mining nodes, we might not need a PKH for mining, but might need one for:
- **Wallet operations** (if running a wallet on the node)
- **Transaction signing**
- **Identity purposes**

Decision needed: Should non-mining nodes also derive wallets?

---

## Recommended Implementation Path

### Phase 1: Test Wallet Derivation
1. Run `nockchain-wallet` inside container to understand exact syntax
2. Create a simple test script that derives wallets
3. Verify output format and parsing

### Phase 2: Create Entrypoint Script
1. Write `docker/entrypoint.sh` that handles derivation
2. Add error handling and logging
3. Make it configurable via environment variables

### Phase 3: Update Dockerfiles
1. Copy entrypoint script into images
2. Set as ENTRYPOINT
3. Keep CMD for nockchain arguments

### Phase 4: Update docker-compose.yml
1. Add CHILD_KEY_INDEX to each service
2. Add FAKENET_SEEDPHRASE (or reference from .env)
3. Test with multiple nodes

### Phase 5: Create Helper Scripts
1. Script to spin up N nodes with sequential indices
2. Script to query all node PKHs
3. Script to fund all derived wallets

---

## Example Multi-Node Setup

Once implemented, you could do:

```yaml
# docker-compose.yml
services:
  nockchain-miner-0:
    environment:
      - CHILD_KEY_INDEX=0  # Gets PKH for index 0
      - FAKENET_SEEDPHRASE=${FAKENET_SEEDPHRASE}

  nockchain-miner-1:
    environment:
      - CHILD_KEY_INDEX=1  # Gets PKH for index 1
      - FAKENET_SEEDPHRASE=${FAKENET_SEEDPHRASE}

  nockchain-node-0:
    environment:
      - CHILD_KEY_INDEX=2  # Gets PKH for index 2
      - FAKENET_SEEDPHRASE=${FAKENET_SEEDPHRASE}
```

Or use a script:
```bash
# Scale up to 5 miners automatically
./scripts/scale-miners.sh 5
# Creates miner-0 through miner-4 with indices 0-4
```

---

## Questions to Resolve

Before implementing, we need to clarify:

1. **What does `nockchain-wallet derive-child` actually do?**
   - Does it require the seed phrase as input?
   - Does it work in fakenet mode?
   - What's the exact output format?

2. **Do non-mining nodes need PKHs?**
   - For what purposes?
   - Can they run without one?

3. **Should wallets be persistent?**
   - Store in volumes?
   - Regenerate each time?
   - Create wallet files?

4. **How many nodes do we need?**
   - Just 1 miner + 1 node?
   - Multiple miners for testing?
   - This affects our docker-compose strategy

5. **Production vs Development:**
   - Is this just for local development?
   - Or should it work for test networks too?

---

## Next Steps

1. **Investigate nockchain-wallet command** - understand its interface
2. **Test wallet derivation manually** - verify it works as expected
3. **Create proof-of-concept entrypoint script** - get one node working
4. **Extend to multi-node setup** - scale the solution

Would you like me to start with investigating the `nockchain-wallet` command to understand its exact interface?
