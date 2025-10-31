#!/bin/bash

WALLETS_DIR="${DATA_DIR}/wallets"
MINER_PKH="${MINING_PKH:-9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV}"

wallet_command() {
    case "$1" in
        create)
            wallet_create "${2:-1}"
            ;;
        fund)
            wallet_fund "$2" "$3"
            ;;
        list)
            wallet_list
            ;;
        *)
            echo "Unknown wallet command: $1"
            exit 1
            ;;
    esac
}

wallet_create() {
    local count=$1
    mkdir -p "$WALLETS_DIR"
    
    for i in $(seq 1 "$count"); do
        # Call nockchain wallet creation
        result=$(docker exec nockchain-fakenet nockchain wallet create --fakenet)
        pkh=$(echo "$result" | grep -oP 'PKH: \K[^\s]+')
        
        # Save wallet info
        echo "$pkh" >> "$WALLETS_DIR/wallets.txt"
        echo "Created wallet $i: $pkh"
    done
    
    echo "Created $count wallet(s)"
}

wallet_fund() {
    local target_pkh=$1
    local amount=$2
    
    echo "Funding $target_pkh with $amount nicks from miner PKH..."
    
    # Create and broadcast transaction
    tx_hash=$(docker exec nockchain-fakenet nockchain tx send \
        --from "$MINER_PKH" \
        --to "$target_pkh" \
        --amount "$amount" \
        --fakenet)
    
    echo "Transaction sent: $tx_hash"
}

wallet_list() {
    if [[ ! -f "$WALLETS_DIR/wallets.txt" ]]; then
        echo "No wallets found"
        return
    fi
    
    echo "Wallets:"
    echo "--------"
    while IFS= read -r pkh; do
        balance=$(docker exec nockchain-fakenet nockchain wallet balance "$pkh" --fakenet)
        echo "$pkh: $balance nicks"
    done < "$WALLETS_DIR/wallets.txt"
}
