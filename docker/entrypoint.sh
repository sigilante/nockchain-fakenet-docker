#!/bin/bash
# Entrypoint script for nockchain Docker containers
# Automatically derives wallet from standard fakenet seed phrase based on child key index

set -e

# Default values
USE_MASTER_PKH="${USE_MASTER_PKH:-false}"
CHILD_KEY_INDEX="${CHILD_KEY_INDEX:-1}"
FAKENET_SEEDPHRASE="${FAKENET_SEEDPHRASE:-farm step rhythm surprise math august panther pulse protect remain anger depend adjust sting enable poet describe stone essay blast click horse hair practice}"
FAKENET_MASTER_PKH="${FAKENET_MASTER_PKH:-9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV}"
WALLET_DATA_DIR="${WALLET_DATA_DIR:-/data/.nockchain-wallet}"

# Fakenet configuration parameters
FAKENET_V1_PHASE="${FAKENET_V1_PHASE:-1}"
FAKENET_POW_LEN="${FAKENET_POW_LEN:-2}"
FAKENET_LOG_DIFFICULTY="${FAKENET_LOG_DIFFICULTY:-1}"
FAKENET_GENESIS_JAM_PATH="${FAKENET_GENESIS_JAM_PATH:-/assets/fakenet-genesis-pow-2-bex-1.jam}"

# Internal-only private gRPC port. nockchain always starts a private gRPC
# listener (used by the standalone zk-pow-mine miner and other operator
# tooling); it must differ from the public gRPC port below or the two binds
# collide (0.0.0.0:5555 already reserves port 5555 on every interface,
# including 127.0.0.1). Never published in docker-compose.yml.
PRIVATE_GRPC_PORT="${PRIVATE_GRPC_PORT:-5554}"

# Ensure wallet data directory exists
mkdir -p "$WALLET_DATA_DIR"

echo "=========================================="
echo "Nockchain Wallet Configuration"
echo "=========================================="
echo "Use Master PKH: $USE_MASTER_PKH"
echo "Child Key Index: $CHILD_KEY_INDEX"
echo "Wallet Data Dir: $WALLET_DATA_DIR"
echo ""

# Function to derive wallet and extract PKH
derive_wallet() {
    local index=$1

    # nockchain-wallet boots against mainnet blockchain-constants unless
    # --fakenet is passed - "command handlers gate fakenet-only behavior"
    # per its own --help. Without it, every lock/note-name the wallet
    # computes (coinbase locks included) uses the wrong constants and
    # silently can't find fakenet notes, even with the correct keys.
    echo "Step 1: Importing seed phrase..."
    nockchain-wallet --fakenet --fakenet-v1-phase "$FAKENET_V1_PHASE" import-keys \
        --seedphrase "$FAKENET_SEEDPHRASE" \
        --version 1 \
        2>&1 | grep -v "^I (" | grep -v "kernel:" | grep -v "serf:" || true

    echo ""
    echo "Step 2: Setting active master address..."
    nockchain-wallet --fakenet --fakenet-v1-phase "$FAKENET_V1_PHASE" set-active-master-address "$FAKENET_MASTER_PKH" \
        2>&1 | grep -v "^I (" | grep -v "kernel:" | grep -v "serf:" || true

    echo ""
    echo "Step 3: Deriving child key at index $index..."
    local output=$(nockchain-wallet --fakenet --fakenet-v1-phase "$FAKENET_V1_PHASE" derive-child "$index" 2>&1)

    # Parse the PKH/Address from the Extended Public Key section
    # The output has two "Address:" lines - we want the second one (from public key section)
    local pkh=$(echo "$output" | grep -A 20 "Extended Public Key:" | grep "^- Address:" | grep -v "N/A" | awk '{print $3}')

    if [ -z "$pkh" ]; then
        echo "ERROR: Failed to parse PKH from wallet derivation output"
        echo "Output was:"
        echo "$output"
        exit 1
    fi

    echo "Derived PKH: $pkh"
    echo "$pkh"
}

# Determine which PKH to use
if [ "$USE_MASTER_PKH" = "true" ]; then
    echo "Using master PKH (no derivation)..."
    DERIVED_PKH="$FAKENET_MASTER_PKH"
    echo "Master PKH: $DERIVED_PKH"
else
    echo "Deriving wallet from child key index $CHILD_KEY_INDEX..."
    DERIVED_PKH=$(derive_wallet "$CHILD_KEY_INDEX")
    # Trim any whitespace from PKH
    DERIVED_PKH=$(echo "$DERIVED_PKH" | tr -d '[:space:]')
fi

echo ""
echo "Successfully derived PKH: $DERIVED_PKH"
echo "PKH length: ${#DERIVED_PKH}"
echo "=========================================="
echo ""

# Build nockchain command as an array to avoid quoting issues
NOCKCHAIN_ARGS=(
    "--fakenet"
    "--bind-public-grpc-addr=0.0.0.0:5555"
    # nockchain binds the private gRPC to 127.0.0.1 unless --bind-private-grpc-addr
    # is given explicitly (--bind-private-grpc-port alone still only listens on
    # loopback) - 0.0.0.0 is fine here since this port is never published to the
    # host in docker-compose.yml, so it's only reachable from other containers on
    # the nockchain-fakenet bridge network, e.g. nockchain-wallet
    # --private-grpc-server-host nockchain-fakenet-miner from another container.
    "--bind-private-grpc-addr" "0.0.0.0:$PRIVATE_GRPC_PORT"
    "--no-default-peers"
    "--bind"
    "/ip4/0.0.0.0/udp/30303/quic-v1"
    "--fakenet-v1-phase"
    "$FAKENET_V1_PHASE"
    "--fakenet-pow-len"
    "$FAKENET_POW_LEN"
    "--fakenet-log-difficulty"
    "$FAKENET_LOG_DIFFICULTY"
    "--fakenet-genesis-jam-path"
    "$FAKENET_GENESIS_JAM_PATH"
)

# nockchain no longer mines itself (no --mine/--mining-pkh flags exist on the
# node binary). Mining is the standalone zk-pow-mine process, which connects
# to this node's private gRPC and pokes solutions back.
if [ "${ENABLE_MINING:-false}" != "true" ]; then
    echo "Starting nockchain in NON-MINING mode..."
    # Add peer connection if PEER_MULTIADDR is set
    if [ -n "${PEER_MULTIADDR}" ]; then
        NOCKCHAIN_ARGS+=(
            "--peer"
            "$PEER_MULTIADDR"
        )
    fi
fi

# Add any additional arguments passed to the container
if [ $# -gt 0 ]; then
    NOCKCHAIN_ARGS+=("$@")
fi

echo "Command: nockchain ${NOCKCHAIN_ARGS[*]}"
echo ""
echo "=========================================="
echo ""

if [ "${ENABLE_MINING:-false}" != "true" ]; then
    exec nockchain "${NOCKCHAIN_ARGS[@]}"
fi

echo "Starting nockchain in MINING mode..."
echo "Mining PKH: $DERIVED_PKH"

# Mining requires two processes: the node, and zk-pow-mine pointed at its
# private gRPC. Run the node in the background, wait for its private gRPC
# to come up, then run the miner in the foreground - and tear both down
# together if either one dies, so a stuck miner doesn't leave the container
# looking healthy with no mining happening.
nockchain "${NOCKCHAIN_ARGS[@]}" &
NODE_PID=$!
MINER_PID=""

cleanup() {
    kill "$NODE_PID" "$MINER_PID" 2>/dev/null || true
    wait "$NODE_PID" "$MINER_PID" 2>/dev/null || true
}
trap cleanup TERM INT

echo "Waiting for node's private gRPC on 127.0.0.1:$PRIVATE_GRPC_PORT..."
until nc -z 127.0.0.1 "$PRIVATE_GRPC_PORT" 2>/dev/null; do
    if ! kill -0 "$NODE_PID" 2>/dev/null; then
        echo "ERROR: nockchain exited before its private gRPC came up"
        exit 1
    fi
    sleep 1
done

# zk-pow-mine defaults to (num_cpus - 1) worker threads, each running a full
# STARK-proving kernel instance. At fakenet's default --fakenet-pow-len 64
# (mainnet-strength difficulty), that's memory-hungry enough to get OOM-killed
# on a host CPU count that doesn't have proportionally large Docker memory
# allocated to it (seen firsthand: 16 vCPUs visible -> 15 threads -> OOM in a
# ~8GB Docker Desktop VM). Fakenet mining doesn't need max throughput, just
# reliable block production, so default low and let it be tuned up.
ZK_POW_MINE_THREADS="${ZK_POW_MINE_THREADS:-2}"

echo "Starting zk-pow-mine against 127.0.0.1:$PRIVATE_GRPC_PORT (num-threads=$ZK_POW_MINE_THREADS)..."
zk-pow-mine \
    --node-addr "http://127.0.0.1:$PRIVATE_GRPC_PORT" \
    --mining-pkh "$DERIVED_PKH" \
    --num-threads "$ZK_POW_MINE_THREADS" &
MINER_PID=$!

# Exit as soon as either process exits, so Docker's restart policy can
# recover instead of leaving a half-alive container.
set +e
wait -n "$NODE_PID" "$MINER_PID"
EXIT_CODE=$?
set -e
cleanup
exit "$EXIT_CODE"
