# Rebuilding After Peer Configuration Update

If you're experiencing "no known peers" issues, this guide will help you rebuild your containers with the new explicit peer configuration.

## What Changed

The Dockerfiles have been updated to include explicit P2P peer configuration:

### Miner Node
```bash
nockchain --mine --fakenet \
  --no-default-peers \
  --bind /ip4/0.0.0.0/udp/30303/quic-v1 \
  --mining-pkh="${MINING_PKH}" \
  --bind-public-grpc-addr=0.0.0.0:5555
```

### Non-Mining Node
```bash
nockchain --fakenet \
  --no-default-peers \
  --bind /ip4/0.0.0.0/udp/30303/quic-v1 \
  --peer /dns4/nockchain-fakenet-miner/udp/30303/quic-v1 \
  --bind-public-grpc-addr=0.0.0.0:5555
```

**Key changes:**
- `--no-default-peers`: Prevents attempts to connect to public backbone nodes
- `--bind /ip4/0.0.0.0/udp/30303/quic-v1`: Explicitly binds P2P to UDP port 30303 with QUIC
- `--peer /dns4/nockchain-fakenet-miner/udp/30303/quic-v1`: Node explicitly connects to miner

## Rebuild Steps

### 1. Stop Running Containers

```bash
docker-compose down
```

### 2. Rebuild Images

You have two options:

**Option A: Quick rebuild** (uses Docker cache):
```bash
docker-compose build
```

**Option B: Full rebuild** (forces fresh build):
```bash
docker-compose build --no-cache
```

Note: A full rebuild takes 20-40 minutes since it recompiles nockchain from source. Use this if you want to ensure everything is fresh.

### 3. Start Services

```bash
docker-compose up -d
```

### 4. Verify P2P Connectivity

Wait 30-60 seconds for nodes to initialize, then run:

```bash
./scripts/check-p2p.sh
```

This script will show you:
- ✓ Container status
- ✓ Network connectivity
- ✓ Peer connection messages
- ✓ Block synchronization

### 5. Watch Logs for Peer Messages

```bash
# Terminal 1 - Miner
docker-compose logs -f nockchain-fakenet-miner | grep -i "peer\|connected"

# Terminal 2 - Node
docker-compose logs -f nockchain-fakenet-node | grep -i "peer\|connected"
```

Look for messages like:
```
INFO peer connected peer_id=...
INFO new peer discovered
INFO established connection to peer
```

## Expected Behavior

### ✅ Success Signs

1. **Peer connection messages in logs:**
   ```
   INFO libp2p_swarm: connection established peer=...
   INFO nockchain: peer connected peer_id=12D3...
   ```

2. **Node discovers miner:**
   ```
   INFO attempting connection to peer=/dns4/nockchain-fakenet-miner/udp/30303/quic-v1
   INFO connection successful
   ```

3. **Block propagation:**
   - Miner logs: `Sealed block number=1`
   - Node logs: `Imported block number=1`

4. **Same block height:**
   Both nodes should report the same latest block number

### ❌ Still Having Issues?

If peer connections still fail after rebuild:

#### Check 1: Verify Images Were Rebuilt

```bash
# Check image build timestamps
docker images | grep nockchain-fakenet

# The images should have recent timestamps (within last few minutes)
```

#### Check 2: Verify Container Commands

```bash
# Check miner command
docker inspect nockchain-fakenet-miner | grep -A 5 Cmd

# Check node command
docker inspect nockchain-fakenet-node | grep -A 5 Cmd
```

You should see `--no-default-peers`, `--bind`, and `--peer` flags.

#### Check 3: Network Connectivity

```bash
# Test UDP port connectivity (note: nc may not support UDP properly)
docker exec nockchain-fakenet-node ping -c 3 nockchain-fakenet-miner

# Verify DNS resolution
docker exec nockchain-fakenet-node nslookup nockchain-fakenet-miner
```

#### Check 4: Review Full Logs

```bash
# See ALL logs from startup
docker-compose logs nockchain-fakenet-miner
docker-compose logs nockchain-fakenet-node

# Look for error messages related to:
# - libp2p
# - peer connections
# - UDP/QUIC
# - multiaddr parsing
```

## Common Issues

### Issue: "Failed to parse multiaddr"

**Symptoms:**
```
ERROR failed to parse peer multiaddr: ...
```

**Solution:**
The multiaddr format may need adjustment. Check nockchain logs for the exact multiaddr format it expects. You might need to use:
- `/ip4/nockchain-fakenet-miner/udp/30303/quic-v1` (IP-based)
- `/dns4/nockchain-fakenet-miner/udp/30303/quic-v1` (DNS-based)
- `/dns6/nockchain-fakenet-miner/udp/30303/quic-v1` (IPv6)

### Issue: "Connection refused" or "No route to host"

**Symptoms:**
```
ERROR connection refused peer=...
WARN failed to dial peer
```

**Solution:**
1. Ensure both containers are on the same Docker network
2. Check if miner is fully initialized before node starts (use `depends_on`)
3. Add healthcheck to miner service

### Issue: Nodes connect but don't sync blocks

**Symptoms:**
- Peer messages show connections
- Miner at block 100, node stuck at block 0

**Possible causes:**
1. Genesis mismatch (nodes started with different genesis)
2. Protocol version incompatibility
3. Block validation errors

**Solution:**
```bash
# Start completely fresh
docker-compose down -v  # WARNING: Deletes all data
docker-compose build --no-cache
docker-compose up -d
```

## Alternative: Use --force-peer Instead

If `--peer` doesn't work reliably, try using `--force-peer` which forces the connection:

Edit `docker/Dockerfile.nockchain-node` line 132:
```bash
CMD ["/bin/sh", "-c", "/usr/local/bin/nockchain --fakenet --bind-public-grpc-addr=0.0.0.0:5555 --no-default-peers --bind /ip4/0.0.0.0/udp/30303/quic-v1 --force-peer /dns4/nockchain-fakenet-miner/udp/30303/quic-v1"]
```

Then rebuild:
```bash
docker-compose build nockchain-fakenet-node
docker-compose up -d
```

## Getting Help

If you're still experiencing issues:

1. **Capture logs:**
   ```bash
   docker-compose logs > debug-logs.txt
   ```

2. **Check nockchain help:**
   ```bash
   docker exec nockchain-fakenet-miner nockchain --help | grep -A 5 peer
   ```

3. **Review nockchain documentation:**
   - [Nockchain GitHub](https://github.com/sigilante/nockchain)
   - [Official Documentation](https://docs.nockchain.org)

4. **File an issue** with:
   - Your Docker and Docker Compose versions
   - Full log output from both containers
   - Output from `./scripts/check-p2p.sh`
