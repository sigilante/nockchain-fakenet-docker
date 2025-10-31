#!/bin/bash

mining_command() {
    case "$1" in
        start)
            mining_start
            ;;
        stop)
            mining_stop
            ;;
        blocks)
            mining_blocks "$2"
            ;;
        *)
            echo "Unknown mining command: $1"
            exit 1
            ;;
    esac
}

mining_start() {
    echo "Starting mining..."
    docker exec -d nockchain-fakenet nockchain mine start
    echo "Mining started in background"
}

mining_stop() {
    echo "Stopping mining..."
    docker exec nockchain-fakenet nockchain mine stop
    echo "Mining stopped"
}

mining_blocks() {
    local count=$1
    echo "Mining $count blocks..."
    
    for i in $(seq 1 "$count"); do
        docker exec nockchain-fakenet nockchain mine block
        echo "Mined block $i/$count"
    done
    
    echo "Finished mining $count blocks"
}
