# Nockchain gRPC API Guide

## ✅ Server Status

If you see this error when running `grpcurl`:
```
Failed to list services: server does not support the reflection API
```

**This is GOOD NEWS!** It means:
- The gRPC server IS responding
- Your sigilante/nockchain fork is working correctly
- The server just doesn't have gRPC reflection enabled

## Finding Proto Files

The gRPC API requires `.proto` files to know what services are available. Here's how to find them:

### Method 1: Extract from Running Container

```bash
# Find proto files in the container
docker exec nockchain-fakenet find /build/nockchain -name "*.proto" 2>/dev/null

# Or check common locations
docker exec nockchain-fakenet ls -la /build/nockchain/proto/
docker exec nockchain-fakenet ls -la /build/nockchain/crates/nockapp-grpc/proto/
```

### Method 2: Get from Repository

```bash
# Clone the sigilante/nockchain fork
git clone https://github.com/sigilante/nockchain.git
cd nockchain

# Find all proto files
find . -name "*.proto"
```

Common locations in nockchain:
- `crates/nockapp-grpc/proto/`
- `proto/nockchain/`
- `crates/nockchain/proto/`

## Using grpcurl with Proto Files

Once you have the proto files:

```bash
# List services with proto files
grpcurl -plaintext \
  -import-path ./path/to/proto \
  -proto nockchain.proto \
  127.0.0.1:5555 list

# Call a specific method
grpcurl -plaintext \
  -import-path ./path/to/proto \
  -proto nockchain.proto \
  -d '{"your": "request"}' \
  127.0.0.1:5555 package.Service/Method
```

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
- Verify you're using sigilante/nockchain fork
