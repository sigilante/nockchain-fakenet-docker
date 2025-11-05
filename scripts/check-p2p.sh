#!/bin/bash
# check-p2p.sh - Verify P2P connectivity between nockchain nodes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=============================================="
echo "  Nockchain P2P Connectivity Check"
echo "=============================================="
echo ""

# Check if containers are running
echo "1. Checking container status..."
MINER_STATUS=$(docker inspect -f '{{.State.Status}}' nockchain-fakenet-miner 2>/dev/null || echo "not found")
NODE_STATUS=$(docker inspect -f '{{.State.Status}}' nockchain-fakenet-node 2>/dev/null || echo "not found")

if [ "$MINER_STATUS" = "running" ]; then
    echo -e "   ${GREEN}✓${NC} Miner container: ${GREEN}running${NC}"
else
    echo -e "   ${RED}✗${NC} Miner container: ${RED}${MINER_STATUS}${NC}"
    exit 1
fi

if [ "$NODE_STATUS" = "running" ]; then
    echo -e "   ${GREEN}✓${NC} Node container: ${GREEN}running${NC}"
else
    echo -e "   ${RED}✗${NC} Node container: ${RED}${NODE_STATUS}${NC}"
    exit 1
fi

echo ""

# Check network connectivity
echo "2. Checking network connectivity..."

# Node -> Miner
if docker exec nockchain-fakenet-node nc -zv nockchain-fakenet-miner 30303 2>&1 | grep -q "succeeded\|open"; then
    echo -e "   ${GREEN}✓${NC} Node can reach miner P2P port (30303)"
else
    echo -e "   ${RED}✗${NC} Node cannot reach miner P2P port (30303)"
fi

# Miner -> Node
if docker exec nockchain-fakenet-miner nc -zv nockchain-fakenet-node 30303 2>&1 | grep -q "succeeded\|open"; then
    echo -e "   ${GREEN}✓${NC} Miner can reach node P2P port (30303)"
else
    echo -e "   ${RED}✗${NC} Miner cannot reach node P2P port (30303)"
fi

echo ""

# Check for peer messages in logs
echo "3. Checking for peer connections in logs..."

MINER_PEERS=$(docker-compose logs --tail=100 nockchain-fakenet-miner 2>/dev/null | grep -i "peer" | wc -l)
NODE_PEERS=$(docker-compose logs --tail=100 nockchain-fakenet-node 2>/dev/null | grep -i "peer" | wc -l)

if [ "$MINER_PEERS" -gt 0 ]; then
    echo -e "   ${GREEN}✓${NC} Miner logs show $MINER_PEERS peer-related messages"
else
    echo -e "   ${YELLOW}⚠${NC} Miner logs show no peer messages"
fi

if [ "$NODE_PEERS" -gt 0 ]; then
    echo -e "   ${GREEN}✓${NC} Node logs show $NODE_PEERS peer-related messages"
else
    echo -e "   ${YELLOW}⚠${NC} Node logs show no peer messages"
fi

echo ""

# Check for recent peer messages
echo "4. Recent peer-related log messages:"
echo ""
echo "   --- Miner ---"
docker-compose logs --tail=20 nockchain-fakenet-miner 2>/dev/null | grep -i "peer\|connected" | tail -5 | sed 's/^/   /' || echo "   No peer messages found"

echo ""
echo "   --- Node ---"
docker-compose logs --tail=20 nockchain-fakenet-node 2>/dev/null | grep -i "peer\|connected" | tail -5 | sed 's/^/   /' || echo "   No peer messages found"

echo ""

# Check block synchronization
echo "5. Checking block synchronization..."

MINER_BLOCKS=$(docker-compose logs --tail=50 nockchain-fakenet-miner 2>/dev/null | grep -i "block" | tail -3)
NODE_BLOCKS=$(docker-compose logs --tail=50 nockchain-fakenet-node 2>/dev/null | grep -i "block\|sync" | tail -3)

if [ -n "$MINER_BLOCKS" ]; then
    echo "   --- Miner recent blocks ---"
    echo "$MINER_BLOCKS" | sed 's/^/   /'
else
    echo "   No block messages in miner logs"
fi

echo ""

if [ -n "$NODE_BLOCKS" ]; then
    echo "   --- Node recent blocks ---"
    echo "$NODE_BLOCKS" | sed 's/^/   /'
else
    echo "   No block messages in node logs"
fi

echo ""
echo "=============================================="
echo ""

# Summary
echo "Summary:"
if [ "$MINER_STATUS" = "running" ] && [ "$NODE_STATUS" = "running" ]; then
    echo -e "${GREEN}Both containers are running${NC}"
    if [ "$MINER_PEERS" -gt 0 ] || [ "$NODE_PEERS" -gt 0 ]; then
        echo -e "${GREEN}P2P communication appears to be working${NC}"
    else
        echo -e "${YELLOW}Containers are running but no peer messages detected yet${NC}"
        echo "Nodes may still be initializing. Wait a few seconds and try again."
    fi
else
    echo -e "${RED}One or more containers are not running${NC}"
fi

echo ""
echo "For more details, see: docs/verifying-p2p-connectivity.md"
