# Scaling Nockchain Nodes

This guide shows different ways to add more nockchain nodes to your fakenet, each with their own derived wallet.

## Default Setup

Out of the box, you get:
- **1 Miner** (uses master PKH)
- **1 Non-Mining Node** (uses master PKH)

Both share the same wallet: `9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV`

## Method 1: Auto-Generate docker-compose Override (Recommended)

The easiest way to add multiple nodes with unique wallets.

### Usage

```bash
# Add 3 additional nodes (child indices 1, 2, 3)
./scripts/add-nodes.sh 3

# Review the generated configuration
cat docker-compose.override.yml

# Start all services (including new nodes)
docker-compose up -d

# Check status
docker-compose ps
```

### What It Does

Creates `docker-compose.override.yml` with additional node services:
- **nockchain-node-2**: Child key index 1, ports 5557 (gRPC), 30305 (P2P)
- **nockchain-node-3**: Child key index 2, ports 5558 (gRPC), 30306 (P2P)
- **nockchain-node-4**: Child key index 3, ports 5559 (gRPC), 30307 (P2P)

Each node gets a unique wallet derived from the fakenet seed phrase.

### Removing Additional Nodes

```bash
# Remove override file and stop all services
rm docker-compose.override.yml
docker-compose down

# Restart just the base services
docker-compose up -d
```

---

## Method 2: Dynamic Node Creation (Quick Testing)

Spin up individual nodes on-demand without modifying configuration files.

### Usage

```bash
# Make sure base services are running
docker-compose up -d

# Build the node image (first time only)
docker-compose build nockchain-fakenet-node

# Spin up a node with child key index 1
./scripts/run-node.sh 1

# Spin up another node with child key index 2 on custom ports
./scripts/run-node.sh 2 5558 30306

# Spin up node with child key index 5
./scripts/run-node.sh 5
```

### Managing Dynamic Nodes

```bash
# View logs
docker logs -f nockchain-node-dynamic-1

# Stop a node
docker stop nockchain-node-dynamic-1

# Remove a node
docker rm nockchain-node-dynamic-1

# List all running nodes
docker ps | grep nockchain-node
```

### Pros and Cons

**Pros:**
- ✅ Very fast - no rebuild needed
- ✅ Flexible - easy to start/stop individual nodes
- ✅ No config file changes

**Cons:**
- ❌ Not persisted - containers don't restart automatically
- ❌ No volume management (data is lost on removal)
- ❌ Manual management required

---

## Method 3: Manual docker-compose Configuration

For permanent, production-like setups where you want full control.

### Step 1: Edit docker-compose.yml

Add a new service to `docker-compose.yml`:

```yaml
services:
  # ... existing services ...

  nockchain-node-2:
    build:
      context: .
      dockerfile: docker/Dockerfile.nockchain-node
      args:
        NOCKCHAIN_VERSION: ${NOCKCHAIN_VERSION:-master}
        PROTOC_VERSION: ${PROTOC_VERSION:-25.1}
    container_name: nockchain-node-2
    volumes:
      - nockchain-node-2-data:/data
      - nockchain-node-2-config:/config
    ports:
      - "${NODE_2_GRPC_PORT:-5557}:5555"
      - "${NODE_2_P2P_PORT:-30305}:30303"
    environment:
      # Derive child key at index 1
      - USE_MASTER_PKH=false
      - CHILD_KEY_INDEX=1
      - FAKENET_SEEDPHRASE=${FAKENET_SEEDPHRASE:-farm step rhythm surprise math august panther pulse protect remain anger depend adjust sting enable poet describe stone essay blast click horse hair practice}
      - FAKENET_MASTER_PKH=${FAKENET_MASTER_PKH:-9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV}
      - FAKENET_V1_PHASE=${FAKENET_V1_PHASE:-1}
      - FAKENET_POW_LEN=${FAKENET_POW_LEN:-2}
      - FAKENET_LOG_DIFFICULTY=${FAKENET_LOG_DIFFICULTY:-1}
      - FAKENET_GENESIS_JAM_PATH=${FAKENET_GENESIS_JAM_PATH:-/assets/fakenet-genesis-pow-2-bex-1.jam}
      - RUST_LOG=${RUST_LOG:-info}
    networks:
      - nockchain-fakenet
    depends_on:
      - nockchain-fakenet-miner
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "5555"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  # ... existing volumes ...
  nockchain-node-2-data:
    driver: local
  nockchain-node-2-config:
    driver: local
```

### Step 2: Configure in .env (Optional)

Add port configurations to `.env`:

```bash
# Node 2 ports
NODE_2_GRPC_PORT=5557
NODE_2_P2P_PORT=30305
```

### Step 3: Start Services

```bash
docker-compose up -d
```

---

## Wallet Derivation Reference

### Child Key Indices

- **Index 0**: Skipped (to avoid confusion with master)
- **Index 1**: First derived wallet
- **Index 2**: Second derived wallet
- **Index 3**: Third derived wallet
- ...and so on

Each child key produces a completely unique PKH.

### Standard Fakenet Seed

```
Seed: farm step rhythm surprise math august panther pulse protect remain anger depend adjust sting enable poet describe stone essay blast click horse hair practice
Master PKH: 9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV
```

### Wallet Assignment

| Container | Wallet Type | Index | PKH |
|-----------|-------------|-------|-----|
| nockchain-fakenet-miner | Master | - | 9yPePjfW... |
| nockchain-fakenet-node | Master | - | 9yPePjfW... |
| nockchain-node-2 | Derived | 1 | (unique) |
| nockchain-node-3 | Derived | 2 | (unique) |
| nockchain-node-4 | Derived | 3 | (unique) |

---

## Port Allocation Guide

To avoid conflicts, use sequential port numbers:

| Node | gRPC Port | P2P Port |
|------|-----------|----------|
| Miner | 5555 | 30303 |
| Node 1 (base) | 5556 | 30304 |
| Node 2 | 5557 | 30305 |
| Node 3 | 5558 | 30306 |
| Node 4 | 5559 | 30307 |
| Node 5 | 5560 | 30308 |

---

## Verification

### Check All Nodes Are Running

```bash
docker ps | grep nockchain
```

You should see all your nodes listed.

### Check Each Node's Wallet

```bash
# Check miner wallet in logs
docker-compose logs nockchain-fakenet-miner | grep "PKH"

# Check node 2 wallet
docker-compose logs nockchain-node-2 | grep "PKH"

# Or for dynamic nodes
docker logs nockchain-node-dynamic-1 | grep "PKH"
```

Each should show a different PKH (except miner and first node which share the master PKH).

### Test gRPC Connectivity

```bash
# Query each node
for port in 5555 5556 5557 5558; do
  echo "Testing port $port..."
  grpcurl -plaintext \
    -import-path crates/nockapp-grpc-proto/proto \
    -proto nockchain/public/v2/nockchain.proto \
    127.0.0.1:$port list
done
```

### Check P2P Connectivity

```bash
# Check peer connections in logs
docker-compose logs | grep -i "peer"
```

All nodes should show peer connections to the miner.

---

## Recommendations

**For Development:**
- Use Method 1 (auto-generate) for quick multi-node testing
- Use Method 2 (dynamic) for experimenting with different configurations

**For Production/Long-Running Tests:**
- Use Method 3 (manual) for full control and persistence
- Set up proper monitoring and health checks
- Use named volumes for data persistence

---

## Troubleshooting

### Port Conflicts

**Error:** `bind: address already in use`

**Solution:** Check which ports are in use:
```bash
netstat -tulpn | grep 555
lsof -i :5557
```

Use different ports in your configuration.

### Nodes Not Connecting to Miner

**Problem:** New nodes show "no known peers"

**Solution:**
1. Check logs for P2P errors: `docker-compose logs <node-name> | grep -i peer`
2. Verify all nodes are on same network: `docker network inspect nockchain-fakenet-docker_nockchain-fakenet`
3. Ensure miner is running first: `docker-compose ps`

### Wallet Derivation Fails

**Problem:** "Failed to parse PKH from wallet derivation output"

**Solution:**
1. Check nockchain-wallet is working: `docker exec <container> nockchain-wallet --help`
2. Verify seed phrase is correct in environment
3. Check logs for full error: `docker-compose logs <node-name>`

### Image Not Found (Dynamic Nodes)

**Problem:** `run-node.sh` says "Docker image not found"

**Solution:** Build the image first:
```bash
docker-compose build nockchain-fakenet-node
```

---

## Examples

### Example 1: 5-Node Fakenet

```bash
# Generate 3 additional nodes (for total of 5)
./scripts/add-nodes.sh 3

# Start everything
docker-compose up -d

# Verify all running
docker-compose ps

# You now have:
# - 1 miner (master PKH)
# - 4 nodes (1 with master PKH, 3 with derived PKHs)
```

### Example 2: Quick Test with Dynamic Nodes

```bash
# Start base services
docker-compose up -d

# Add some test nodes quickly
./scripts/run-node.sh 1
./scripts/run-node.sh 2
./scripts/run-node.sh 3

# Test them
for i in 1 2 3; do
  docker logs nockchain-node-dynamic-$i | grep "Successfully derived PKH"
done

# Clean up when done
docker stop nockchain-node-dynamic-{1,2,3}
docker rm nockchain-node-dynamic-{1,2,3}
```

### Example 3: Mix of Manual and Dynamic

```bash
# Have permanent nodes via docker-compose.override.yml
./scripts/add-nodes.sh 2
docker-compose up -d

# Plus some temporary dynamic nodes for testing
./scripts/run-node.sh 10 6000 31000
./scripts/run-node.sh 11 6001 31001

# Total: 2 base + 2 permanent + 2 dynamic = 6 nodes
```
