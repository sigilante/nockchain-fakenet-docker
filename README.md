# `nockchain-fakenet-docker`

This repository contains a Docker Compose setup for running a local fakenet of Nockchain nodes. This setup is useful for NockApp application development, testing, and experimentation with Nockchain without needing to connect to the livenet.

**Status:**  🚧 Work in Progress 🚧

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
