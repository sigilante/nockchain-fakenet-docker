#!/bin/bash
set -e

echo "Setting up poker development environment..."

# Create 4 player wallets
./nockapp-cli wallet create 4

# Fund each wallet with initial balance
for pkh in $(cat data/wallets/wallets.txt); do
    ./nockapp-cli wallet fund "$pkh" 65536000
done

# Mine a few blocks to confirm transactions
./nockapp-cli mine blocks 5

# Create checkpoint
./nockapp-cli checkpoint wallets-funded

echo "Poker dev environment ready!"
echo "4 player wallets created and funded"
echo "Checkpoint 'wallets-funded' created"
