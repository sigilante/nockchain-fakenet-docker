#!/bin/bash
# add-nodes.sh - Generate docker-compose configuration for additional nockchain nodes
# Usage: ./scripts/add-nodes.sh <number_of_nodes>

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <number_of_nodes>"
    echo ""
    echo "Example: $0 3"
    echo "  Creates docker-compose.override.yml with 3 additional nodes"
    echo "  Nodes will have child key indices 1, 2, 3"
    echo "  Ports will be 5557, 5558, 5559 (gRPC) and 30305, 30306, 30307 (P2P)"
    exit 1
fi

NUM_NODES=$1

if ! [[ "$NUM_NODES" =~ ^[0-9]+$ ]] || [ "$NUM_NODES" -lt 1 ]; then
    echo "Error: Number of nodes must be a positive integer"
    exit 1
fi

OVERRIDE_FILE="docker-compose.override.yml"

echo "Generating $OVERRIDE_FILE with $NUM_NODES additional node(s)..."
echo ""

# Start the override file
cat > "$OVERRIDE_FILE" <<'EOF'
# Auto-generated docker-compose override file
# Created by: scripts/add-nodes.sh
# This file adds additional nockchain nodes with unique derived wallets
#
# To remove these nodes: rm docker-compose.override.yml && docker-compose down
# To apply changes: docker-compose up -d

services:
EOF

# Generate each additional node
for i in $(seq 1 $NUM_NODES); do
    NODE_NAME="nockchain-node-$((i+1))"  # Start from node-2 (node-1 is in base compose)
    CHILD_INDEX=$i                        # Child indices: 1, 2, 3...
    GRPC_PORT=$((5556 + i))              # Ports: 5557, 5558, 5559...
    P2P_PORT=$((30304 + i))              # Ports: 30305, 30306, 30307...

    cat >> "$OVERRIDE_FILE" <<EOF

  # Additional node $((i+1)) with derived wallet (child index $CHILD_INDEX)
  $NODE_NAME:
    build:
      context: .
      dockerfile: docker/Dockerfile.nockchain-node
      args:
        NOCKCHAIN_VERSION: \${NOCKCHAIN_VERSION:-master}
        PROTOC_VERSION: \${PROTOC_VERSION:-25.1}
    container_name: $NODE_NAME
    volumes:
      - ${NODE_NAME}-data:/data
      - ${NODE_NAME}-config:/config
    ports:
      - "\${NODE_${i}_GRPC_PORT:-$GRPC_PORT}:5555"
      - "\${NODE_${i}_P2P_PORT:-$P2P_PORT}:30303"
    environment:
      # Wallet settings - derive child key at index $CHILD_INDEX
      - USE_MASTER_PKH=false
      - CHILD_KEY_INDEX=$CHILD_INDEX
      - FAKENET_SEEDPHRASE=\${FAKENET_SEEDPHRASE:-farm step rhythm surprise math august panther pulse protect remain anger depend adjust sting enable poet describe stone essay blast click horse hair practice}
      - FAKENET_MASTER_PKH=\${FAKENET_MASTER_PKH:-9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV}
      # Fakenet settings
      - FAKENET_V1_PHASE=\${FAKENET_V1_PHASE:-1}
      - FAKENET_POW_LEN=\${FAKENET_POW_LEN:-2}
      - FAKENET_LOG_DIFFICULTY=\${FAKENET_LOG_DIFFICULTY:-1}
      - FAKENET_GENESIS_JAM_PATH=\${FAKENET_GENESIS_JAM_PATH:-/assets/fakenet-genesis-pow-2-bex-1.jam}
      - RUST_LOG=\${RUST_LOG:-info}
    networks:
      - nockchain-fakenet
    depends_on:
      - nockchain-fakenet-miner
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "5555"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
EOF
done

# Add volumes section
cat >> "$OVERRIDE_FILE" <<EOF

volumes:
EOF

for i in $(seq 1 $NUM_NODES); do
    NODE_NAME="nockchain-node-$((i+1))"
    cat >> "$OVERRIDE_FILE" <<EOF
  ${NODE_NAME}-data:
    driver: local
  ${NODE_NAME}-config:
    driver: local
EOF
done

echo "✓ Generated $OVERRIDE_FILE"
echo ""
echo "Configuration:"

for i in $(seq 1 $NUM_NODES); do
    NODE_NAME="nockchain-node-$((i+1))"
    CHILD_INDEX=$i
    GRPC_PORT=$((5556 + i))
    P2P_PORT=$((30304 + i))

    echo "  - $NODE_NAME"
    echo "    Child Key Index: $CHILD_INDEX"
    echo "    gRPC Port: $GRPC_PORT"
    echo "    P2P Port: $P2P_PORT"
    echo ""
done

echo "Next steps:"
echo "  1. Review the generated file: cat $OVERRIDE_FILE"
echo "  2. Start all services: docker-compose up -d"
echo "  3. Check status: docker-compose ps"
echo "  4. View logs: docker-compose logs -f"
echo ""
echo "To remove additional nodes:"
echo "  rm $OVERRIDE_FILE && docker-compose down"
echo ""
