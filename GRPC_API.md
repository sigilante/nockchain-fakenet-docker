# Nockchain gRPC API Guide

## ✅ Server Status

If you see this error when running `grpcurl`:
```
Failed to list services: server does not support the reflection API
```

**This is GOOD NEWS!** It means:
- The gRPC server IS responding
- Your nockchain node is working correctly
- The server just doesn't have gRPC reflection enabled

## Working with the gRPC API

### Proto Files Location

The proto files are included in the nockchain/nockchain repository at:
```
crates/nockapp-grpc-proto/proto/nockchain/
├── common/v1/
│   ├── blockchain.proto
│   ├── pagination.proto
│   └── primitives.proto
├── common/v2/
│   └── blockchain.proto
├── public/v1/
│   └── nockchain.proto
├── public/v2/
│   └── nockchain.proto (current version)
├── private/v1/
│   └── nockapp.proto
└── monitoring/v1/
    └── monitoring.proto
```

### Using grpcurl

**Important:** The proto files have imports, so you must:
1. Set the import path to the proto root directory
2. Reference the proto file with its full path from that root

```bash
# List available services
grpcurl -plaintext \
  -import-path crates/nockapp-grpc-proto/proto \
  -proto nockchain/public/v2/nockchain.proto \
  127.0.0.1:5555 list

# List methods in the service
grpcurl -plaintext \
  -import-path crates/nockapp-grpc-proto/proto \
  -proto nockchain/public/v2/nockchain.proto \
  127.0.0.1:5555 list nockchain.public.v2.NockchainService

# Describe the service (see all method signatures)
grpcurl -plaintext \
  -import-path crates/nockapp-grpc-proto/proto \
  -proto nockchain/public/v2/nockchain.proto \
  127.0.0.1:5555 describe nockchain.public.v2.NockchainService

# Call a specific method
grpcurl -plaintext \
  -import-path crates/nockapp-grpc-proto/proto \
  -proto nockchain/public/v2/nockchain.proto \
  -d '{"your": "request"}' \
  127.0.0.1:5555 nockchain.public.v2.NockchainService/MethodName
```

**Note:** Server reflection is NOT enabled, so proto files are required.

## Alternative: Use Postman or BloomRPC

If grpcurl is too complicated, use a GUI tool:

1. **Postman** - Has built-in gRPC support
2. **BloomRPC** - Open source gRPC GUI client
3. **Kreya** - Modern API client with gRPC support

Just point them to `127.0.0.1:5555` and import the proto files.

## Verifying Server is Running

```bash
# Check if port is open
nc -zv 127.0.0.1 5555

# Or with netstat inside container
docker exec nockchain-fakenet netstat -tulpn | grep 5555

# Check logs for gRPC server startup
docker-compose logs nockchain-node | grep -i grpc
docker-compose logs nockchain-node | grep "EnablePublicServer"
```

## `nockchain-wallet` Defaults to a Real External Server

This is a gotcha specific to the `nockchain-wallet` binary, separate from the node's gRPC API above: `nockchain-wallet`'s `--client` flag defaults to `public`, and `--public-grpc-server-addr` defaults to **`23.252.122.18:5556`** - a real server on the actual network, hardcoded upstream. Any wallet command needing current chain state (balance, `create-tx` without `--notes-csv`, sending, etc.) will silently dial that address instead of your local fakenet node unless you override it:

```bash
docker exec nockchain-fakenet-miner nockchain-wallet \
  --fakenet --fakenet-v1-phase 1 \
  --client private --private-grpc-server-port 5554 \
  list-notes
```

Use port **5554** (this repo's `--bind-private-grpc-port`), not the wallet's own default of 5555. Commands that only touch local key material (`import-keys`, `derive-child`, `list-active-addresses`, etc.) never make this call and are unaffected - see [README.md](README.md#nockchain-wallet-defaults-to-a-real-external-server---not-your-local-node) for the full breakdown.

**Don't drop `--fakenet --fakenet-v1-phase 1`** even once you're pointed at the right server: `nockchain-wallet` boots against *mainnet* blockchain-constants unless `--fakenet` is passed - "command handlers gate fakenet-only behavior" per its own `--help`. Without it, every lock/note-name the wallet computes (including coinbase locks) uses the wrong constants, so sync connects fine, reports the correct chain height, and still silently returns zero notes even for a PKH that's actually earning mining rewards. This bit us: connectivity, keys, and PKH all matched, and it still took directly comparing the coinbase lock's Hoon construction (`hoon/common/tx-engine.hoon`) against what the wallet computes to find it.

`--client private` also only ever targets `127.0.0.1` upstream - the example above works because it execs into the miner container itself. To reach a private gRPC from *outside* that container (another container by Docker DNS name, a host-mapped address, etc.), this repo builds `nockchain-wallet` from a small fork (see README's [Repository Source](README.md#repository-source)) that adds `--private-grpc-server-host`:

```bash
docker exec nockchain-fakenet-node nockchain-wallet \
  --fakenet --fakenet-v1-phase 1 \
  --client private \
  --private-grpc-server-host nockchain-fakenet-miner \
  --private-grpc-server-port 5554 \
  list-notes
```

## Troubleshooting

**"context deadline exceeded" on localhost:5555:**
- Try `127.0.0.1:5555` instead of `localhost:5555`
- Check if container is running: `docker-compose ps`
- Check port mapping: `docker-compose port nockchain-node 5555`

**Server appears to be down:**
- Container might have crashed: `docker-compose logs nockchain-node`
- Port might not be mapped: check `docker-compose.yml`

**Still can't connect:**
- Rebuild with fresh image: `docker-compose build --no-cache`
- Verify the container built successfully and `nockchain --help` lists `--bind-public-grpc-addr`
