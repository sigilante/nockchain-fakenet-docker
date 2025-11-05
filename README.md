# `nockchain-fakenet-docker`

This repository contains a Docker Compose setup for running a local fakenet of Nockchain nodes. This setup is useful for NockApp application development, testing, and experimentation with Nockchain without needing to connect to the livenet.

**Status:**  Working fakenet nodes.

* Upstream Nockchain distribution zorp-corp/nockchain currently has the public gRPC server disabled by default, making wallet operations and queries inaccessible from outside the node. This Docker setup uses a forked version sigilante/nockchain which enables the public gRPC server, allowing full API access. See [Technical Notes](#technical-notes) for details.

* Needs improvement: Automated verification of P2P connectivity between miner and non-mining node. See [Verifying P2P Connectivity](#verifying-p2p-connectivity) for manual steps.

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

    **Note:** This build uses the `sigilante/nockchain` fork which has the public gRPC server enabled, allowing full API access.

## Architecture

This setup runs two nockchain nodes:

1. **Mining Node** (`nockchain-fakenet-miner`):
   - Runs with `--mine` flag
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
    NOCKCHAIN_VERSION: v1.0.0  # or 'master' for latest
    NOCKUP_VERSION: v1.0.0     # or 'master' for latest
```

### Environment Variables

Configure the node via environment variables in `docker-compose.yml`:

- `MINING_PKH`: Public key hash for mining rewards
- `FAKENET`: Enable fakenet mode (true/false)
- `POW_LEN`: Proof-of-work difficulty (lower = easier)
- `COINBASE_TIMELOCK_MIN`: Minimum coinbase maturity time

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

This Docker build currently uses **`sigilante/nockchain`** instead of the upstream `zorp-corp/nockchain` repository.

**Why?** The upstream nockchain hardcodes the public gRPC server as disabled (`NockchainAPIConfig::DisablePublicServer` in `main.rs`), making the API inaccessible even with correct CLI flags. The `sigilante/nockchain` fork includes a fix that enables the public gRPC server, allowing full API functionality.

**What's different?**
- Public gRPC server is enabled (uses `EnablePublicServer`)
- The `--bind-public-grpc-addr` flag now works correctly
- External wallet operations and blockchain queries are accessible

**Future plans:** Once a PR with these changes is merged into `zorp-corp/nockchain`, this Dockerfile will be updated to use the upstream repository again.

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
- [Nockchain GitHub Repository (upstream)](https://github.com/zorp-corp/nockchain)
- [Nockchain Fork with gRPC enabled (currently used)](https://github.com/sigilante/nockchain)
