#!/bin/bash

CHECKPOINTS_DIR="${DATA_DIR}/checkpoints"

checkpoint_save() {
    local name=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local checkpoint_path="$CHECKPOINTS_DIR/${name}_${timestamp}"
    
    mkdir -p "$checkpoint_path"
    
    echo "Creating checkpoint: $name"
    
    # Export current state
    docker exec nockchain-fakenet nockchain \
        --export-state-jam "/data/checkpoint.jam"
    
    # Copy exported state and wallet info
    cp "$DATA_DIR/checkpoint.jam" "$checkpoint_path/state.jam"
    cp -r "$WALLETS_DIR" "$checkpoint_path/wallets"
    
    # Save metadata
    cat > "$checkpoint_path/metadata.json" <<EOF
{
    "name": "$name",
    "timestamp": "$timestamp",
    "created_at": "$(date -Iseconds)"
}
EOF
    
    echo "Checkpoint saved: $name"
}

checkpoint_restore() {
    local name=$1
    local latest=$(ls -d "$CHECKPOINTS_DIR/${name}_"* 2>/dev/null | sort -r | head -n1)
    
    if [[ -z "$latest" ]]; then
        echo "Checkpoint not found: $name"
        exit 1
    fi
    
    echo "Restoring checkpoint: $name"
    
    # Stop node
    docker-compose stop nockchain-node
    
    # Restore state
    cp "$latest/state.jam" "$DATA_DIR/genesis.jam"
    cp -r "$latest/wallets" "$WALLETS_DIR"
    
    # Restart node with restored state
    docker-compose up -d nockchain-node
    
    echo "Checkpoint restored: $name"
}
