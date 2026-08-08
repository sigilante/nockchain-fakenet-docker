# `nockchain-fakenet-docker`

This repository contains a Docker Compose setup for running a local fakenet of Nockchain nodes. This setup is useful for NockApp application development, testing, and experimentation with Nockchain without needing to connect to the livenet.

**Status:**  Working fakenet nodes.

* This Docker setup builds from the upstream `nockchain/nockchain` distribution. It previously used a fork, `sigilante/nockchain`, to work around the public gRPC server being hardcoded off; that fix has since been merged upstream. See [Technical Notes](#technical-notes) for details, including a breaking change upstream made to mining in the process.

* Needs improvement: Automated verification of P2P connectivity between miner and non-mining node. See [Verifying P2P Connectivity](#verifying-p2p-connectivity) for manual steps.

* Needs improvement: Linux Docker images on macOS Silicon are not currently available.

![](./img/hero.png)

## Features

- **Dual-node setup**: Separate mining and non-mining nodes
  - **Miner Node**: Produces blocks and maintains consensus
  - **Non-Mining Node**: For wallet operations, queries, and application development
- **Self-contained build**: Builds entire nockchain ecosystem from source - no host dependencies required
  - `nockchain` - Main node binary
  - `nockchain-wallet` - Wallet management tool
  - `hoon` - Hoon runtime/interpreter
  - `hoonc` - Hoon compiler
  - `nockup` - NockApp project management tool
- **Multi-stage Docker build**: Optimized image size with separate build and runtime stages
- **Named volumes**: Persistent data storage without host filesystem coupling
- **Development CLI**: Helper scripts for wallet management, mining, and checkpoints
- **Security**: Runs as non-root user inside container
- **Serial PKHs**: Easy wallet management with master and child keys for multiple nodes (see [Automated Wallet Configuration](#automated-wallet-configuration))

## Prerequisites

* Docker (20.10+)
* Docker Compose (2.0+)

**Note:** You do NOT need to install Rust, Cargo, or nockchain on your host machine. Everything is built inside Docker.

## Quick Start

1. Clone this repository:

    ```bash
    git clone https://github.com/sigilante/nockchain-fakenet-docker.git
    cd nockchain-fakenet-docker
    ```

2. (Optional) Configure environment variables:

    ```bash
    cp .env.example .env
    # Edit .env to customize settings
    ```

3. Build and start the fakenet:

    ```bash
    docker-compose up -d
    ```

    The first build will take 20-40 minutes as it compiles the entire nockchain ecosystem from source (nockchain, nockchain-wallet, hoon, hoonc, and nockup). Subsequent builds use Docker layer caching and are much faster.

4. Check the status:

    ```bash
    docker-compose ps
    docker-compose logs -f nockchain-fakenet-miner
    docker-compose logs -f nockchain-fakenet-node
    ```

5. Access the fakenet:

    Nockchain uses **gRPC** for its API (not HTTP RPC). The fakenet runs two services:

    **Miner Node** (produces blocks):
    - **gRPC API**: `localhost:5555`
    - **P2P Network**: `localhost:30303`

    **Non-Mining Node** (for wallet operations):
    - **gRPC API**: `localhost:5556` ← **Use this for wallet operations**
    - **P2P Network**: `localhost:30304`

    **Note:** This build uses upstream `nockchain/nockchain`, passing `--bind-public-grpc-addr` to enable the public gRPC server for full API access.

## Architecture

This setup runs two nockchain nodes:

1. **Mining Node** (`nockchain-fakenet-miner`):
   - Runs `nockchain` plus a standalone `zk-pow-mine` process pointed at its private gRPC
   - Produces blocks and maintains the blockchain
   - Receives mining rewards to the configured PKH

2. **Non-Mining Node** (`nockchain-fakenet-node`):
   - Runs without mining
   - Connects to the miner node via P2P
   - Ideal for wallet operations and queries
   - Lower resource usage (no mining work)

Both nodes share the same fakenet network and communicate via P2P to maintain consensus.

### P2P Configuration

The nodes are pre-configured with explicit peer connections:

- **Both nodes** use `--no-default-peers` to prevent connection attempts to public backbone nodes
- **Both nodes** bind to `/ip4/0.0.0.0/udp/30303/quic-v1` (QUIC over UDP)
- **Non-mining node** explicitly connects to miner using `--peer /dns4/nockchain-fakenet-miner/udp/30303/quic-v1`

This configuration ensures the nodes discover and connect to each other immediately on startup, even in an isolated Docker environment.

### Automated Wallet Configuration

The setup uses the standard fakenet credentials with smart wallet management:

**Standard Fakenet Credentials:**
```
Seed Phrase: farm step rhythm surprise math august panther pulse protect remain anger depend adjust sting enable poet describe stone essay blast click horse hair practice
Master PKH: 9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV
```

**Default Wallet Configuration:**
- **Miner Node**: Uses master PKH (no derivation needed)
- **First Non-Mining Node**: Also uses master PKH (shares wallet with miner)
- **Additional Nodes**: Derive unique child keys starting from index 1

This approach allows the miner and first node to share the same wallet for convenience, while additional nodes get their own unique wallets.

**Adding More Nodes with Unique Wallets:**
```yaml
nockchain-node-2:
  environment:
    - USE_MASTER_PKH=false        # Enable child key derivation
    - CHILD_KEY_INDEX=1            # First child key (we skip index 0)
    - FAKENET_SEEDPHRASE=farm...   # Standard seed phrase

nockchain-node-3:
  environment:
    - USE_MASTER_PKH=false
    - CHILD_KEY_INDEX=2            # Second child key
    - FAKENET_SEEDPHRASE=farm...
```

**Note:** Child index 0 is skipped to avoid confusion with the master key. Additional nodes start with index 1, 2, 3, etc.

## Scaling to Multiple Nodes

Need more nodes? We provide helper scripts to easily scale your fakenet:

### Quick Method: Auto-Generate Nodes

```bash
# Add 3 additional nodes (child indices 1, 2, 3)
./scripts/add-nodes.sh 3

# Start all services
docker-compose up -d
```

This creates `docker-compose.override.yml` with:
- **nockchain-node-2**: Child key 1, ports 5557/30305
- **nockchain-node-3**: Child key 2, ports 5558/30306
- **nockchain-node-4**: Child key 3, ports 5559/30307

Each gets a unique wallet derived from the fakenet seed phrase.

### Dynamic Method: Spin Up Individual Nodes

```bash
# Quick one-off nodes for testing
./scripts/run-node.sh 1        # Node with child key 1
./scripts/run-node.sh 2 5558   # Node with child key 2, custom port
```

**See [docs/scaling-nodes.md](docs/scaling-nodes.md) for complete guide** including:
- Manual docker-compose configuration
- Port allocation strategies
- Wallet derivation details
- Troubleshooting multi-node setups

## Verifying P2P Connectivity

To check if your miner and node are successfully communicating:

```bash
# Quick automated check
./scripts/check-p2p.sh
```

This script will verify:
- Both containers are running
- Network connectivity between containers
- Peer connection messages in logs
- Block synchronization status

For detailed verification steps and troubleshooting, see: [docs/verifying-p2p-connectivity.md](docs/verifying-p2p-connectivity.md)

**Quick manual check:**
```bash
# Watch both nodes in real-time (use two terminals)
docker-compose logs -f nockchain-fakenet-miner
docker-compose logs -f nockchain-fakenet-node

# Look for peer connection and block propagation messages
```

## Using the Development CLI

The `scripts/nockapp-cli` tool provides convenient commands for development:

```bash
# Create wallets
./scripts/nockapp-cli wallet create 4

# Fund a wallet
./scripts/nockapp-cli wallet fund <pkh> 65536000

# Mine blocks
./scripts/nockapp-cli mine blocks 10

# Save checkpoint
./scripts/nockapp-cli checkpoint wallets-funded

# Show status
./scripts/nockapp-cli status
```

## Configuration

### Build Arguments

You can specify the versions to build in your `.env` file or directly in `docker-compose.yml`:

```yaml
build:
  args:
    NOCKCHAIN_VERSION: v1.0.0  # or 'master' for latest (nockup builds from this same checkout)
```

### Environment Variables

Configure the node via environment variables in `docker-compose.yml`:

- `MINING_PKH`: Public key hash for mining rewards
- `FAKENET`: Enable fakenet mode (true/false)
- `POW_LEN`: Proof-of-work difficulty (lower = easier)

## Data Persistence

Data is stored in named Docker volumes (separate for miner and node):

```bash
# List volumes
docker volume ls | grep nockchain

# Inspect a volume
docker volume inspect nockchain-fakenet-docker_nockchain-miner-data
docker volume inspect nockchain-fakenet-docker_nockchain-node-data

# Backup miner data
docker run --rm -v nockchain-fakenet-docker_nockchain-miner-data:/data \
  -v $(pwd)/backup:/backup ubuntu tar czf /backup/nockchain-miner-data.tar.gz /data

# Backup node data
docker run --rm -v nockchain-fakenet-docker_nockchain-node-data:/data \
  -v $(pwd)/backup:/backup ubuntu tar czf /backup/nockchain-node-data.tar.gz /data

# Remove all data (fresh start)
docker-compose down -v
```

## Troubleshooting

**Build fails with Rust compilation errors:**
- The build uses the latest master branch by default
- Try pinning to a specific version tag in `docker-compose.yml`

**Container exits immediately:**
- Check miner logs: `docker-compose logs nockchain-fakenet-miner`
- Check node logs: `docker-compose logs nockchain-fakenet-node`
- Verify health check: `docker inspect nockchain-fakenet-miner`

**Port already in use:**
- Change port mappings in `.env` or `docker-compose.yml`
- Example in `.env`: `MINER_GRPC_PORT=15555` or `NODE_GRPC_PORT=15556`

**gRPC API not responding:**
- Check container logs: look for `server_config=EnablePublicServer`
- Verify bind address shows `0.0.0.0:5555` not `127.0.0.1:5555`
- Ensure ports 5555 and 5556 are not already in use on your host
- Try connecting to the non-mining node at `localhost:5556` for wallet operations

**Nodes not connecting to each other:**
- Check if both containers are on the same Docker network: `docker network inspect nockchain-fakenet-docker_nockchain-fakenet`
- Verify P2P ports are correctly mapped
- Check logs for P2P connection messages

## Technical Notes

### Repository Source

This Docker build uses upstream **`nockchain/nockchain`**. It previously used a fork, **`sigilante/nockchain`**, because upstream hardcoded the public gRPC server as disabled (`NockchainAPIConfig::DisablePublicServer` in `main.rs`), making the API inaccessible even with correct CLI flags. That fix (enabling `EnablePublicServer` when `--bind-public-grpc-addr` is passed) has since been merged upstream, so the fork is no longer needed for this reason.

### Mining is now a separate process

Somewhere along the way, upstream also extracted mining out of the `nockchain` binary entirely: `--mine` and `--mining-pkh` no longer exist as `nockchain` CLI flags. Mining is now the standalone `zk-pow-mine` binary (crate `zk-pow-miner`), which connects to a running node's **private** gRPC endpoint, watches for mining candidates, and pokes solutions back.

To keep this repo's one-container-per-role setup, the miner image (`docker/Dockerfile.nockchain-miner`) now also builds `zk-pow-mine`, and `docker/entrypoint.sh` runs both processes in the miner container: `nockchain` in the background (with `--bind-private-grpc-port` set to an internal-only port, distinct from the public gRPC port to avoid a bind conflict), and `zk-pow-mine` pointed at that private port in the foreground. If either process dies, the container exits so Docker's restart policy can recover it. The non-mining node container is unaffected — it only ever ran `nockchain` by itself.

One related flag also disappeared: `--fakenet-coinbase-timelock-min` no longer exists on the `nockchain` CLI, so `FAKENET_COINBASE_TIMELOCK_MIN` has been removed from `.env.example` and `docker-compose.yml`.

**Memory note:** `zk-pow-mine` defaults to `(host CPUs - 1)` worker threads, each running a full STARK-proving kernel instance - on a host with many cores, that can be more concurrent proving work than a modestly-sized Docker Desktop VM can hold, and the miner container gets OOM-killed. `docker/entrypoint.sh` now caps this via `--num-threads`, controlled by `ZK_POW_MINE_THREADS` (default `2`). Raise it if you've given Docker more memory and want faster block production; check `docker inspect <container> --format '{{.State.OOMKilled}}'` if the miner container keeps exiting.

**Difficulty note:** this repo defaults to the easy fakenet genesis (`FAKENET_POW_LEN=2`, `FAKENET_LOG_DIFFICULTY=1`, `fakenet-genesis-pow-2-bex-1.jam`) so local mining stays fast. `FAKENET_POW_LEN=64` / `fakenet-genesis-pow-64-bex-5.jam` mimics mainnet-grade difficulty and will mine genesis plus a couple of blocks before slowing to a crawl on typical dev hardware - only switch to it if you specifically want to exercise real PoW difficulty, and change `FAKENET_POW_LEN`, `FAKENET_LOG_DIFFICULTY`, and `FAKENET_GENESIS_JAM_PATH` together (they must match the same genesis, not be swapped independently).

### `nockchain-wallet` defaults to a real external server - not your local node

`nockchain-wallet`'s `--client` flag defaults to `public`, and `--public-grpc-server-addr` defaults to **`23.252.122.18:5556`** - a real server on the actual network, hardcoded upstream (`crates/nockchain-wallet/src/connection.rs`). Any wallet command that needs current chain state (balance checks, `create-tx` without `--notes-csv`, sending, etc.) will silently dial out to that address instead of this stack's local fakenet node, unless you override it.

Commands that only touch local key material - `import-keys`, `derive-child`, `derive-child-batch`, `set-active-master-address`, `list-active-addresses`, `keygen`, `export-keys`, `show-*` - never sync and never make this call, which is why `docker/entrypoint.sh`'s automated wallet derivation is unaffected. But if you exec into a container to check a balance or send a transaction, explicitly target the local node's private gRPC or you'll be querying (and leaking your watched addresses to) the public server instead of your fakenet chain:

```bash
docker exec nockchain-fakenet-miner nockchain-wallet \
  --client private --private-grpc-server-port 5554 \
  list-notes
```

Note the port: this repo binds the node's private gRPC to **5554** (`--bind-private-grpc-port`, see above), not the wallet's own default of 5555 - `nockchain-wallet`'s default `--private-grpc-server-port` won't reach it either.

## Development

To rebuild after making changes:

```bash
# Rebuild with no cache
docker-compose build --no-cache

# Rebuild and restart
docker-compose up -d --build
```

## References

- [Nockchain Documentation](https://docs.nockchain.org/)
- [NockApp Development and Testing](https://docs.nockchain.org/nockapp/what-is-nockapp/development-and-testing)
- [Nockchain GitHub Repository (upstream, used by this build)](https://github.com/nockchain/nockchain)
- [zk-pow-miner](https://github.com/nockchain/nockchain/tree/master/crates/zk-pow-miner) - standalone mining process used by the miner container
