#!/bin/bash
# run-node.sh - Spin up an individual nockchain node with a derived wallet
# Usage: ./scripts/run-node.sh <child_key_index> [grpc_port] [p2p_port]

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <child_key_index> [grpc_port] [p2p_port]"
    echo ""
    echo "Arguments:"
    echo "  child_key_index  - Child key index for wallet derivation (1, 2, 3...)"
    echo "  grpc_port        - gRPC port on host (default: 5557)"
    echo "  p2p_port         - P2P port on host (default: 30305)"
    echo ""
    echo "Examples:"
    echo "  $0 1              # Node with child key 1, ports 5557:5555, 30305:30303"
    echo "  $0 2 5558 30306   # Node with child key 2, custom ports"
    echo "  $0 5              # Node with child key 5, default ports"
    echo ""
    echo "Use child index 0 to skip derivation and use master PKH:"
    echo "  $0 0              # Use master PKH (no derivation)"
    exit 1
fi

CHILD_KEY_INDEX=$1
GRPC_PORT=${2:-5557}
P2P_PORT=${3:-30305}

# Defaults from .env.example
FAKENET_SEEDPHRASE="${FAKENET_SEEDPHRASE:-farm step rhythm surprise math august panther pulse protect remain anger depend adjust sting enable poet describe stone essay blast click horse hair practice}"
FAKENET_MASTER_PKH="${FAKENET_MASTER_PKH:-9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV}"
NOCKCHAIN_IMAGE="${NOCKCHAIN_IMAGE:-nockchain-fakenet-docker-nockchain-fakenet-node}"
NETWORK_NAME="${NETWORK_NAME:-nockchain-fakenet-docker_nockchain-fakenet}"

# Determine if we should use master PKH
if [ "$CHILD_KEY_INDEX" -eq 0 ]; then
    USE_MASTER_PKH="true"
    WALLET_DESC="master PKH"
else
    USE_MASTER_PKH="false"
    WALLET_DESC="child key index $CHILD_KEY_INDEX"
fi

CONTAINER_NAME="nockchain-node-dynamic-$CHILD_KEY_INDEX"

echo "=========================================="
echo "Starting Nockchain Node"
echo "=========================================="
echo "Container Name: $CONTAINER_NAME"
echo "Wallet: $WALLET_DESC"
echo "gRPC Port: $GRPC_PORT (host) -> 5555 (container)"
echo "P2P Port: $P2P_PORT (host) -> 30303 (container)"
echo "Network: $NETWORK_NAME"
echo ""

# Check if image exists
if ! docker images "$NOCKCHAIN_IMAGE" | grep -q "$NOCKCHAIN_IMAGE"; then
    echo "Error: Docker image '$NOCKCHAIN_IMAGE' not found"
    echo "Please build the image first:"
    echo "  docker-compose build nockchain-fakenet-node"
    exit 1
fi

# Check if network exists
if ! docker network ls | grep -q "$NETWORK_NAME"; then
    echo "Error: Docker network '$NETWORK_NAME' not found"
    echo "Please start the base services first:"
    echo "  docker-compose up -d"
    exit 1
fi

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping existing container..."
    docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
fi

echo "Starting container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    -p "${GRPC_PORT}:5555" \
    -p "${P2P_PORT}:30303" \
    -e "USE_MASTER_PKH=$USE_MASTER_PKH" \
    -e "CHILD_KEY_INDEX=$CHILD_KEY_INDEX" \
    -e "FAKENET_SEEDPHRASE=$FAKENET_SEEDPHRASE" \
    -e "FAKENET_MASTER_PKH=$FAKENET_MASTER_PKH" \
    -e "FAKENET=true" \
    -e "POW_LEN=2" \
    -e "RUST_LOG=info" \
    -e "PEER_MULTIADDR=/dns4/nockchain-fakenet-miner/udp/30303/quic-v1" \
    "$NOCKCHAIN_IMAGE"

echo ""
echo "✓ Container started successfully!"
echo ""
echo "Access points:"
echo "  gRPC API: localhost:$GRPC_PORT"
echo "  P2P: localhost:$P2P_PORT"
echo ""
echo "Useful commands:"
echo "  View logs: docker logs -f $CONTAINER_NAME"
echo "  Stop node: docker stop $CONTAINER_NAME"
echo "  Remove node: docker rm $CONTAINER_NAME"
echo "  Check status: docker ps | grep $CONTAINER_NAME"
echo ""
echo "To query this node via gRPC:"
echo "  grpcurl -plaintext \\"
echo "    -import-path crates/nockapp-grpc-proto/proto \\"
echo "    -proto nockchain/public/v2/nockchain.proto \\"
echo "    127.0.0.1:$GRPC_PORT list"
echo ""
