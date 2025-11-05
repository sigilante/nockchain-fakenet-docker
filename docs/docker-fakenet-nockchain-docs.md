# Docker Fakenet Setup

The Docker Fakenet provides a containerized development environment for building and testing NockApps. This setup eliminates the need to install Rust, Cargo, or compile nockchain locally, making it easy to spin up a local test network in minutes.

## Overview

The Docker Fakenet consists of:

- **Mining Node**: Produces blocks and maintains the blockchain
- **Non-Mining Nodes**: Execute queries and wallet operations without mining overhead
- **Automated Wallet Derivation**: Each node receives a unique wallet derived from the standard fakenet seed phrase
- **P2P Networking**: Nodes communicate via libp2p with QUIC transport
- **gRPC API Access**: Full API access for NockApp development and testing

All components are built from source in reproducible Docker containers, ensuring consistency across development environments.

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+

No Rust toolchain or nockchain installation required on the host system.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/sigilante/nockchain-fakenet-docker.git
cd nockchain-fakenet-docker

# Build and start the network (first build takes 20-40 minutes)
docker-compose build
docker-compose up -d

# Verify services are running
docker-compose ps

# Check logs
docker-compose logs -f
```

Once started, the network provides:

- **Mining Node**: `localhost:5555` (gRPC)
- **Non-Mining Node**: `localhost:5556` (gRPC)

Both nodes use the standard fakenet credentials:

```
Seed Phrase: farm step rhythm surprise math august panther pulse protect remain anger depend adjust sting enable poet describe stone essay blast click horse hair practice
Master PKH: 9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV
```

## Network Architecture

### Node Configuration

The default setup runs two nodes:

1. **Mining Node** (`nockchain-fakenet-miner`)
   - Mines blocks with adjustable proof-of-work difficulty
   - Receives mining rewards to the master PKH
   - Binds gRPC API to `0.0.0.0:5555`
   - P2P: `/ip4/0.0.0.0/udp/30303/quic-v1`

2. **Non-Mining Node** (`nockchain-fakenet-node`)
   - Synchronizes with the mining node via P2P
   - Ideal for wallet operations and NockApp queries
   - Binds gRPC API to `0.0.0.0:5555` (mapped to host port 5556)
   - Explicitly connects to miner: `/dns4/nockchain-fakenet-miner/udp/30303/quic-v1`

Both nodes share the same wallet by default, simplifying development workflows where a single account is sufficient.

### Wallet Derivation

The setup uses BIP39 hierarchical deterministic wallet derivation:

- **Master Key**: Used by the mining node and first non-mining node
- **Child Keys**: Additional nodes derive unique wallets using child key indices 1, 2, 3, etc.
- **Deterministic**: Wallets are reproducible from the seed phrase

Child index 0 is intentionally skipped to avoid confusion with the master key.

### P2P Networking

Nodes use libp2p for peer-to-peer communication:

- **Transport**: QUIC over UDP (port 30303)
- **Discovery**: Explicit peer configuration (no public bootstrap nodes)
- **Isolation**: `--no-default-peers` prevents connection attempts to mainnet

The non-mining node explicitly connects to the mining node using Docker DNS resolution, ensuring immediate peer discovery in the isolated container environment.

## Accessing the Network

### gRPC API

Query the network using `grpcurl` or any gRPC client:

```bash
# List available services
grpcurl -plaintext \
  -import-path crates/nockapp-grpc-proto/proto \
  -proto nockchain/public/v2/nockchain.proto \
  127.0.0.1:5555 list

# List service methods
grpcurl -plaintext \
  -import-path crates/nockapp-grpc-proto/proto \
  -proto nockchain/public/v2/nockchain.proto \
  127.0.0.1:5555 list nockchain.public.v2.NockchainService

# Describe a service
grpcurl -plaintext \
  -import-path crates/nockapp-grpc-proto/proto \
  -proto nockchain/public/v2/nockchain.proto \
  127.0.0.1:5555 describe nockchain.public.v2.NockchainService
```

The proto files are located in the `crates/nockapp-grpc-proto/proto` directory of the nockchain repository.

### Wallet Operations

Execute wallet commands inside containers:

```bash
# Create a new wallet
docker exec -it nockchain-fakenet-node nockchain-wallet create --fakenet

# Import the standard fakenet keys
docker exec -it nockchain-fakenet-node nockchain-wallet import-keys \
  --seedphrase "farm step rhythm surprise math august panther pulse protect remain anger depend adjust sting enable poet describe stone essay blast click horse hair practice" \
  --version 1

# Derive a child key
docker exec -it nockchain-fakenet-node nockchain-wallet derive-child 1
```

### Verifying Network Operation

Check that nodes are communicating correctly:

```bash
# Automated health check
./scripts/check-p2p.sh
```

This script verifies:
- Container health status
- Network connectivity between nodes
- Peer connection establishment
- Block synchronization

Expected output includes peer connection messages and block propagation between nodes.

## Scaling the Network

### Adding Nodes Automatically

Generate additional nodes with unique wallets:

```bash
# Add 3 nodes (total of 5 nodes including base setup)
./scripts/add-nodes.sh 3

# Start all services
docker-compose up -d
```

This creates `docker-compose.override.yml` with:

- **nockchain-node-2**: Child key index 1, ports 5557/30305
- **nockchain-node-3**: Child key index 2, ports 5558/30306
- **nockchain-node-4**: Child key index 3, ports 5559/30307

Each node derives a unique wallet from the standard seed phrase.

### Dynamic Node Creation

For temporary testing, spin up individual nodes without modifying configuration:

```bash
# Start a node with child key index 1
./scripts/run-node.sh 1

# Start a node with child key index 2 on custom ports
./scripts/run-node.sh 2 5558 30306

# View logs
docker logs -f nockchain-node-dynamic-1

# Cleanup
docker stop nockchain-node-dynamic-1
docker rm nockchain-node-dynamic-1
```

See [Scaling Nodes](scaling-nodes.md) for detailed multi-node configuration strategies.

## Configuration

### Environment Variables

Configure the network via `.env` or environment variables:

```bash
# Wallet configuration
FAKENET_SEEDPHRASE="farm step rhythm..."
FAKENET_MASTER_PKH="9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV"

# Fakenet parameters
FAKENET=true
POW_LEN=2                      # Proof-of-work difficulty (lower = faster)
COINBASE_TIMELOCK_MIN=0        # Coinbase maturity in blocks

# Port configuration
MINER_GRPC_PORT=5555
MINER_P2P_PORT=30303
NODE_GRPC_PORT=5556
NODE_P2P_PORT=30304

# Build versions
NOCKCHAIN_VERSION=master       # Git branch/tag to build
NOCKUP_VERSION=master
```

### Adjusting Mining Difficulty

Modify proof-of-work difficulty in `.env`:

```bash
POW_LEN=2    # Easy (development)
POW_LEN=4    # Medium
POW_LEN=6    # Harder
```

Restart services to apply changes:

```bash
docker-compose down
docker-compose up -d
```

### Data Persistence

Blockchain data is stored in Docker volumes:

```bash
# List volumes
docker volume ls | grep nockchain

# Backup miner data
docker run --rm \
  -v nockchain-fakenet-docker_nockchain-miner-data:/data \
  -v $(pwd)/backup:/backup \
  ubuntu tar czf /backup/miner-data.tar.gz /data

# Fresh start (deletes all data)
docker-compose down -v
docker-compose up -d
```

## NockApp Development Workflow

### 1. Start the Fakenet

```bash
docker-compose up -d
```

### 2. Develop Your NockApp

Use `nockup` inside a container or on your host:

```bash
# Create new NockApp project
nockup new my-nockapp
cd my-nockapp

# Develop your application
# Edit src/my-nockapp.hoon
```

### 3. Deploy to Fakenet

```bash
# Deploy via the non-mining node
nockup deploy --endpoint http://localhost:5556 --fakenet
```

### 4. Test and Query

```bash
# Query your NockApp via gRPC
grpcurl -plaintext \
  -import-path crates/nockapp-grpc-proto/proto \
  -proto nockchain/public/v2/nockchain.proto \
  -d '{"your": "request"}' \
  127.0.0.1:5556 nockchain.public.v2.NockchainService/YourMethod
```

### 5. Monitor Activity

```bash
# Watch miner logs
docker-compose logs -f nockchain-fakenet-miner

# Watch node logs
docker-compose logs -f nockchain-fakenet-node

# Check P2P connectivity
./scripts/check-p2p.sh
```

## Troubleshooting

### Containers Exit Immediately

**Check logs for errors:**

```bash
docker-compose logs nockchain-fakenet-miner
docker-compose logs nockchain-fakenet-node
```

**Common causes:**
- Wallet derivation failure
- Port conflicts
- Invalid configuration

### No Peer Connections

**Verify network connectivity:**

```bash
./scripts/check-p2p.sh
```

**Check P2P configuration:**

```bash
docker-compose logs | grep -i "peer"
docker-compose logs | grep -i "libp2p"
```

Nodes should show peer connections within 30 seconds of startup.

### Port Already in Use

**Identify conflicting processes:**

```bash
lsof -i :5555
netstat -tulpn | grep 5555
```

**Change ports in `.env`:**

```bash
MINER_GRPC_PORT=15555
NODE_GRPC_PORT=15556
```

Then restart:

```bash
docker-compose down
docker-compose up -d
```

### Slow Block Production

**Check mining configuration:**

```bash
docker-compose logs nockchain-fakenet-miner | grep -i "pow\|difficulty"
```

**Adjust difficulty in `.env`:**

```bash
POW_LEN=2  # Lower value = faster blocks
```

### Clean Rebuild

**Force rebuild without cache:**

```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

## Technical Details

### Build Process

The Docker build performs the following steps:

1. **Install Rust toolchains**: Stable for nockchain, nightly for nockup
2. **Install protoc 25.1**: Required for proto3 optional fields
3. **Clone repositories**: nockchain (sigilante fork) and nockup
4. **Build binaries**: nockchain, nockchain-wallet, hoon, hoonc, nockup
5. **Create runtime image**: Ubuntu 22.04 with compiled binaries

Build time: 20-40 minutes on first run. Subsequent builds use Docker layer caching.

### Entrypoint Script

Each container executes an entrypoint script that:

1. Checks the `USE_MASTER_PKH` environment variable
2. If true: Uses the master PKH directly
3. If false: Derives child key at `CHILD_KEY_INDEX` using:
   - `nockchain-wallet import-keys --seedphrase "..."`
   - `nockchain-wallet set-active-master-address "..."`
   - `nockchain-wallet derive-child <index>`
4. Parses the derived PKH from output
5. Starts nockchain with the appropriate configuration

### Network Isolation

The Docker network is isolated from public nockchain networks:

- Custom bridge network: `nockchain-fakenet`
- No default peers: `--no-default-peers` flag
- Explicit peer connections only
- No connection attempts to mainnet bootstrap nodes

This ensures a clean, reproducible development environment.

### Why the sigilante Fork?

The official zorp-corp/nockchain repository hardcodes the public gRPC server as disabled. The sigilante fork enables the public gRPC server (`EnablePublicServer`), allowing full API access for development.

Once these changes are merged upstream, the Dockerfile will be updated to use the official repository.

## Repository Structure

```
nockchain-fakenet-docker/
├── docker/
│   ├── Dockerfile.nockchain-miner    # Mining node image
│   ├── Dockerfile.nockchain-node     # Non-mining node image
│   └── entrypoint.sh                  # Wallet derivation script
├── scripts/
│   ├── add-nodes.sh                   # Generate additional nodes
│   ├── run-node.sh                    # Dynamic node creation
│   ├── check-p2p.sh                   # P2P health check
│   └── nockapp-cli                    # Development helper
├── docs/
│   ├── scaling-nodes.md               # Multi-node setup guide
│   ├── verifying-p2p-connectivity.md  # Network verification
│   ├── automated-wallet-generation.md # Wallet architecture
│   └── GRPC_API.md                    # gRPC usage guide
├── docker-compose.yml                 # Base service definitions
├── .env.example                       # Configuration template
└── README.md                          # Quick start guide
```

## Additional Resources

- [Scaling Nodes Guide](scaling-nodes.md) - Multi-node configuration strategies
- [P2P Connectivity Verification](verifying-p2p-connectivity.md) - Network debugging
- [Automated Wallet Generation](automated-wallet-generation.md) - Wallet architecture details
- [gRPC API Guide](GRPC_API.md) - Working with the gRPC API

## Contributing

This project is maintained at: https://github.com/sigilante/nockchain-fakenet-docker

Issues and pull requests welcome.
