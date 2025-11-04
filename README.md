# `nockchain-fakenet-docker`

This repository contains a Docker Compose setup for running a local fakenet of Nockchain nodes. This setup is useful for NockApp application development, testing, and experimentation with Nockchain without needing to connect to the livenet.

**Status:**  🚧 Work in Progress 🚧

![](./img/hero.png)

## Features

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
    docker-compose logs -f nockchain-node
    ```

4. Access the fakenet:

    Nockchain uses **gRPC** for its API (not HTTP RPC). The fakenet services are accessible at:
    - P2P Network: `localhost:30303`

    **Note:** The public gRPC API (port 5555) is currently **disabled** in the nockchain source code (`main.rs` hardcodes `DisablePublicServer`). The container runs and mines successfully, but the gRPC API is not accessible for external wallet operations or queries until this is fixed upstream.

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
- Example: `"5555:5555"` → `"15555:5555"`

**gRPC API not responding:**
- The public gRPC server is currently **hardcoded as disabled** in nockchain source code
- Check container logs: you will see `server_config=DisablePublicServer`
- This is an upstream issue - see Technical Notes below

## Technical Notes

### Public gRPC Server Status

⚠️ **Known Limitation:** The nockchain source code currently hardcodes the public gRPC server as disabled in `crates/nockchain/src/main.rs`:

```rust
nockchain::init_with_kernel(
    cli,
    KERNEL,
    prover_hot_state.as_slice(),
    NockchainAPIConfig::DisablePublicServer,  // Hardcoded!
)
```

This means the gRPC API on port 5555 is not accessible even though:
- The container runs successfully
- Mining works correctly
- The `--bind-public-grpc-addr` CLI flag exists but has no effect

**Impact:** External wallet operations and blockchain queries via gRPC are not currently possible.

**Solution:** This requires an upstream fix in the nockchain repository to either:
1. Add a CLI flag to control this setting (e.g., `--enable-public-grpc`)
2. Make it conditional based on `--fakenet` mode
3. Enable it by default and add `--disable-public-grpc` flag instead

A PR will be submitted to the nockchain maintainers to address this.

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
