# Verifying P2P Connectivity Between Nodes

This guide shows how to verify that your miner and non-mining node are successfully communicating via P2P.

## Quick Check Commands

### 1. Check Container Logs for P2P Messages

**Miner logs:**
```bash
docker-compose logs nockchain-fakenet-miner | grep -i "peer\|p2p\|connected"
```

**Node logs:**
```bash
docker-compose logs nockchain-fakenet-node | grep -i "peer\|p2p\|connected"
```

Look for messages like:
- `peer connected`
- `new peer`
- `peer_count`
- `syncing with peer`
- `discovered peer`

### 2. Check if Nodes Are on the Same Network

```bash
# Inspect the Docker network
docker network inspect nockchain-fakenet-docker_nockchain-fakenet

# Should show both containers in the "Containers" section
```

### 3. Verify Both Containers Are Running

```bash
docker-compose ps
```

Both `nockchain-fakenet-miner` and `nockchain-fakenet-node` should show as "Up".

## Detailed Verification

### Check Block Synchronization

The non-mining node should sync blocks from the miner. Check if both nodes report the same block height:

```bash
# Check miner logs for latest block
docker-compose logs --tail=50 nockchain-fakenet-miner | grep -i "block\|height"

# Check node logs for block sync
docker-compose logs --tail=50 nockchain-fakenet-node | grep -i "block\|height\|sync"
```

If the node is syncing properly, you should see messages about:
- Receiving blocks
- Updating chain height
- Validating blocks

### Check Network Connectivity Between Containers

```bash
# Test if node can reach miner's P2P port
docker exec nockchain-fakenet-node nc -zv nockchain-fakenet-miner 30303

# Test if miner can reach node's P2P port
docker exec nockchain-fakenet-miner nc -zv nockchain-fakenet-node 30303
```

Both should report "succeeded" or "open".

### Use gRPC to Query Network Status

If nockchain exposes peer information via gRPC, you can query it:

```bash
# List available gRPC methods (look for peer/network related methods)
grpcurl -plaintext \
  -import-path crates/nockapp-grpc-proto/proto \
  -proto nockchain/public/v2/nockchain.proto \
  127.0.0.1:5555 list nockchain.public.v2.NockchainService

# Describe methods to see what info they return
grpcurl -plaintext \
  -import-path crates/nockapp-grpc-proto/proto \
  -proto nockchain/public/v2/nockchain.proto \
  127.0.0.1:5555 describe nockchain.public.v2.NockchainService
```

Look for methods like:
- `GetPeers`
- `GetNetworkInfo`
- `GetNodeInfo`

### Monitor Logs in Real-Time

Watch both nodes simultaneously to see P2P activity:

```bash
# Terminal 1 - Miner logs
docker-compose logs -f nockchain-fakenet-miner

# Terminal 2 - Node logs (in a separate terminal)
docker-compose logs -f nockchain-fakenet-node
```

When the miner produces a new block, you should see:
1. **Miner**: Log showing block mined
2. **Node**: Log showing block received and validated

## What Good P2P Communication Looks Like

### ✅ Healthy Signs

1. **Log messages showing peer connections:**
   ```
   INFO peer connected peer_id=... addr=nockchain-fakenet-miner:30303
   ```

2. **Block propagation:**
   - Miner logs: "Mined block #123"
   - Node logs: "Received block #123" or "Imported block #123"

3. **Same block height:**
   - Both nodes report the same latest block number

4. **Network connectivity tests succeed:**
   - `nc -zv` commands show connections work

### ❌ Problem Signs

1. **No peer connections in logs**
   - Indicates nodes can't discover each other

2. **Node stuck at block 0 while miner is at block 100+**
   - Node isn't receiving blocks from miner

3. **Connection refused errors:**
   ```
   ERROR failed to connect to peer error="connection refused"
   ```

4. **Firewall or network isolation messages:**
   ```
   WARN no peers connected
   ```

## Troubleshooting No Communication

If nodes aren't communicating:

### 1. Verify Network Configuration

```bash
# Check both containers are on the same network
docker inspect nockchain-fakenet-miner | grep -A 10 Networks
docker inspect nockchain-fakenet-node | grep -A 10 Networks
```

Both should show `nockchain-fakenet-docker_nockchain-fakenet`.

### 2. Check P2P Port Configuration

```bash
# Verify ports are exposed
docker inspect nockchain-fakenet-miner | grep -A 5 ExposedPorts
docker inspect nockchain-fakenet-node | grep -A 5 ExposedPorts
```

Should include `30303/tcp`.

### 3. Restart with Fresh Data

Sometimes nodes need fresh data to establish connections:

```bash
# Stop all services
docker-compose down

# Remove volumes (WARNING: deletes all blockchain data)
docker volume rm nockchain-fakenet-docker_nockchain-miner-data
docker volume rm nockchain-fakenet-docker_nockchain-node-data

# Start fresh
docker-compose up -d

# Watch logs
docker-compose logs -f
```

### 4. Check if Nodes Need Explicit Peer Configuration

Some blockchain nodes need explicit peer addresses. Check if nockchain supports:
- `--bootnodes` flag
- `--peer` or `--connect` flags
- A config file with peer addresses

You may need to configure the node to explicitly connect to the miner:

```yaml
# In docker-compose.yml, you might need to add:
command: >
  /bin/sh -c "/usr/local/bin/nockchain
  --fakenet
  --bind-public-grpc-addr=0.0.0.0:5555
  --connect=nockchain-fakenet-miner:30303"
```

### 5. Check Nockchain Documentation

Nockchain may have specific P2P configuration requirements. Check:
- `nockchain --help` for networking flags
- Nockchain docs for network configuration
- Example configurations in the nockchain repository

## Automated Health Check

Create a simple script to verify connectivity:

```bash
#!/bin/bash
# check-p2p.sh

echo "=== Checking P2P Connectivity ==="

echo -n "Miner container status: "
docker inspect -f '{{.State.Status}}' nockchain-fakenet-miner

echo -n "Node container status: "
docker inspect -f '{{.State.Status}}' nockchain-fakenet-node

echo -n "Network connectivity (node -> miner): "
docker exec nockchain-fakenet-node nc -zv nockchain-fakenet-miner 30303 2>&1 | tail -1

echo -n "Network connectivity (miner -> node): "
docker exec nockchain-fakenet-miner nc -zv nockchain-fakenet-node 30303 2>&1 | tail -1

echo "=== Recent Peer Messages (Miner) ==="
docker-compose logs --tail=10 nockchain-fakenet-miner | grep -i peer

echo "=== Recent Peer Messages (Node) ==="
docker-compose logs --tail=10 nockchain-fakenet-node | grep -i peer
```

Make it executable and run:
```bash
chmod +x check-p2p.sh
./check-p2p.sh
```
