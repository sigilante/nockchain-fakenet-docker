# `nockchain-fakenet-docker`

This repository contains a Docker Compose setup for running a local fakenet of Nockchain nodes. This setup is useful for NockApp application development, testing, and experimentation with Nockchain without needing to connect to the livenet.

**Status:**  🚧 Work in Progress 🚧

![](./img/hero.png)

## Features

- **Self-contained build**: Builds nockchain from source - no host dependencies required
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

    The first build will take 15-30 minutes as it compiles nockchain from source. Subsequent builds use Docker layer caching and are much faster.

4. Check the status:

    ```bash
    docker-compose ps
    docker-compose logs -f nockchain-node
    ```

4. Access the fakenet:

    You can access the fakenet services at:
    - RPC: `http://localhost:8545`
    - WebSocket: `ws://localhost:8546`
    - gRPC: `http://localhost:5555`

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

You can specify the nockchain version to build:

```yaml
build:
  args:
    NOCKCHAIN_VERSION: v1.0.0  # or 'master' for latest
```

### Environment Variables

Configure the node via environment variables in `docker-compose.yml`:

- `MINING_PKH`: Public key hash for mining rewards
- `FAKENET`: Enable fakenet mode (true/false)
- `POW_LEN`: Proof-of-work difficulty (lower = easier)
- `COINBASE_TIMELOCK_MIN`: Minimum coinbase maturity time

## Data Persistence

Data is stored in named Docker volumes:

```bash
# List volumes
docker volume ls | grep nockchain

# Inspect a volume
docker volume inspect nockchain-fakenet-docker_nockchain-data

# Backup data
docker run --rm -v nockchain-fakenet-docker_nockchain-data:/data \
  -v $(pwd)/backup:/backup ubuntu tar czf /backup/nockchain-data.tar.gz /data

# Remove all data (fresh start)
docker-compose down -v
```

## Troubleshooting

**Build fails with Rust compilation errors:**
- The build uses the latest master branch by default
- Try pinning to a specific version tag in `docker-compose.yml`

**Container exits immediately:**
- Check logs: `docker-compose logs nockchain-node`
- Verify health check: `docker inspect nockchain-fakenet`

**Port already in use:**
- Change port mappings in `docker-compose.yml`
- Example: `"8545:8545"` → `"18545:8545"`

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
- [Nockchain GitHub Repository](https://github.com/zorp-corp/nockchain)
