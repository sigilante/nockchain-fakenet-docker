#!/bin/bash
# Entrypoint script for nockchain Docker containers
# Automatically derives wallet from standard fakenet seed phrase based on child key index

set -e

# Default values
CHILD_KEY_INDEX="${CHILD_KEY_INDEX:-0}"
FAKENET_SEEDPHRASE="${FAKENET_SEEDPHRASE:-farm step rhythm surprise math august panther pulse protect remain anger depend adjust sting enable poet describe stone essay blast click horse hair practice}"
FAKENET_MASTER_PKH="${FAKENET_MASTER_PKH:-9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV}"
WALLET_DATA_DIR="${WALLET_DATA_DIR:-/data/.nockchain-wallet}"

# Ensure wallet data directory exists
mkdir -p "$WALLET_DATA_DIR"

echo "=========================================="
echo "Nockchain Wallet Derivation"
echo "=========================================="
echo "Child Key Index: $CHILD_KEY_INDEX"
echo "Wallet Data Dir: $WALLET_DATA_DIR"
echo ""

# Function to derive wallet and extract PKH
derive_wallet() {
    local index=$1

    echo "Step 1: Importing seed phrase..."
    nockchain-wallet import-keys \
        --seedphrase "$FAKENET_SEEDPHRASE" \
        --version 1 \
        2>&1 | grep -v "^I (" | grep -v "kernel:" | grep -v "serf:" || true

    echo ""
    echo "Step 2: Setting active master address..."
    nockchain-wallet set-active-master-address "$FAKENET_MASTER_PKH" \
        2>&1 | grep -v "^I (" | grep -v "kernel:" | grep -v "serf:" || true

    echo ""
    echo "Step 3: Deriving child key at index $index..."
    local output=$(nockchain-wallet derive-child "$index" 2>&1)

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

# Derive the wallet for this container's index
echo "Deriving wallet..."
DERIVED_PKH=$(derive_wallet "$CHILD_KEY_INDEX")

# Trim any whitespace from PKH
DERIVED_PKH=$(echo "$DERIVED_PKH" | tr -d '[:space:]')

echo ""
echo "Successfully derived PKH: $DERIVED_PKH"
echo "PKH length: ${#DERIVED_PKH}"
echo "=========================================="
echo ""

# Build nockchain command as an array to avoid quoting issues
NOCKCHAIN_ARGS=(
    "--fakenet"
    "--bind-public-grpc-addr=0.0.0.0:5555"
    "--no-default-peers"
    "--bind"
    "/ip4/0.0.0.0/udp/30303/quic-v1"
)

if [ "${ENABLE_MINING:-false}" = "true" ]; then
    echo "Starting nockchain in MINING mode..."
    echo "Mining PKH: $DERIVED_PKH"
    NOCKCHAIN_ARGS+=(
        "--mine"
        "--mining-pkh=$DERIVED_PKH"
    )
else
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

# Execute nockchain with proper argument array
exec nockchain "${NOCKCHAIN_ARGS[@]}"
