#!/bin/bash
set -e

echo "==================================================================="
echo "Testing Nockchain Fakenet Docker Setup"
echo "==================================================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Start the container
echo -e "\n${YELLOW}Test 1: Starting container...${NC}"
docker-compose up -d
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Container started successfully${NC}"
else
    echo -e "${RED}✗ Failed to start container${NC}"
    exit 1
fi

# Test 2: Check container status
echo -e "\n${YELLOW}Test 2: Checking container status...${NC}"
sleep 5
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✓ Container is running${NC}"
    docker-compose ps
else
    echo -e "${RED}✗ Container is not running${NC}"
    docker-compose logs
    exit 1
fi

# Test 3: Check container logs
echo -e "\n${YELLOW}Test 3: Checking container logs (last 20 lines)...${NC}"
docker-compose logs --tail=20 nockchain-node

# Test 4: Verify binaries are accessible
echo -e "\n${YELLOW}Test 4: Verifying binaries are installed...${NC}"
docker exec nockchain-fakenet which nockchain && echo -e "${GREEN}✓ nockchain found${NC}" || echo -e "${RED}✗ nockchain not found${NC}"
docker exec nockchain-fakenet which nockchain-wallet && echo -e "${GREEN}✓ nockchain-wallet found${NC}" || echo -e "${RED}✗ nockchain-wallet not found${NC}"
docker exec nockchain-fakenet which hoon && echo -e "${GREEN}✓ hoon found${NC}" || echo -e "${RED}✗ hoon not found${NC}"
docker exec nockchain-fakenet which hoonc && echo -e "${GREEN}✓ hoonc found${NC}" || echo -e "${RED}✗ hoonc not found${NC}"
docker exec nockchain-fakenet which nockup && echo -e "${GREEN}✓ nockup found${NC}" || echo -e "${RED}✗ nockup not found${NC}"

# Test 5: Check binary versions
echo -e "\n${YELLOW}Test 5: Checking binary versions...${NC}"
docker exec nockchain-fakenet nockchain --version 2>&1 || echo "nockchain version check failed"
docker exec nockchain-fakenet nockchain-wallet --version 2>&1 || echo "nockchain-wallet version check failed"
docker exec nockchain-fakenet hoon --version 2>&1 || echo "hoon version check failed"
docker exec nockchain-fakenet hoonc --version 2>&1 || echo "hoonc version check failed"
docker exec nockchain-fakenet nockup --version 2>&1 || echo "nockup version check failed"

# Test 6: Wait for service to be ready
echo -e "\n${YELLOW}Test 6: Waiting for nockchain service to be ready...${NC}"
echo "Waiting up to 60 seconds for RPC endpoint..."
for i in {1..60}; do
    if curl -sf http://localhost:8545 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ RPC endpoint is responding${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}✗ RPC endpoint not responding after 60 seconds${NC}"
        echo "Container logs:"
        docker-compose logs --tail=50 nockchain-node
        exit 1
    fi
    sleep 1
done

# Test 7: Test RPC endpoint
echo -e "\n${YELLOW}Test 7: Testing RPC endpoint...${NC}"
curl -s http://localhost:8545 || echo "RPC returned status: $?"

# Test 8: Check health status
echo -e "\n${YELLOW}Test 8: Checking container health status...${NC}"
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' nockchain-fakenet 2>/dev/null || echo "no healthcheck")
echo "Health status: $HEALTH"

echo -e "\n==================================================================="
echo -e "${GREEN}Basic tests completed!${NC}"
echo -e "==================================================================="
echo ""
echo "Next steps:"
echo "  1. Check logs: docker-compose logs -f nockchain-node"
echo "  2. Access container: docker exec -it nockchain-fakenet bash"
echo "  3. Test wallet: docker exec nockchain-fakenet nockchain-wallet --help"
echo "  4. Stop container: docker-compose down"
echo ""
