#!/bin/bash

###############################################################################
# Stabilization Script - Restart and clean up for healthy state
###############################################################################

cd /home/dtri/docker_open5gs

COMPOSE_FILE="sa-vonr-deploy.yaml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Open5GS Stabilization & Health Recovery                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}This will:${NC}"
echo "  1. Stop all services gracefully"
echo "  2. Clear old log files"
echo "  3. Restart services for clean state"
echo "  4. Wait for services to stabilize"
echo "  5. Verify health status"

read -p $'\n\nContinue? (y/n): ' -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Step 1: Stop services
echo -e "\n${BLUE}[1/5] Stopping services...${NC}"
docker compose -f $COMPOSE_FILE down > /dev/null 2>&1
sleep 2
echo -e "${GREEN}✓ Services stopped${NC}"

# Step 2: Clear old logs
echo -e "\n${BLUE}[2/5] Clearing old log files...${NC}"
rm -f log/*.log
mkdir -p log
echo -e "${GREEN}✓ Logs cleared${NC}"

# Step 3: Restart services
echo -e "\n${BLUE}[3/5] Starting services (this may take 30-60 seconds)...${NC}"
docker compose -f $COMPOSE_FILE up -d > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to start services${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Services started${NC}"

# Step 4: Wait for stabilization
echo -e "\n${BLUE}[4/5] Waiting for services to stabilize...${NC}"

waited=0
max_wait=60

while [ $waited -lt $max_wait ]; do
    running=$(docker compose -f $COMPOSE_FILE ps --format "{{.Status}}" | grep -c "Up")
    total=$(docker compose -f $COMPOSE_FILE ps --format "{{.Service}}" | wc -l)

    if [ "$running" == "$total" ]; then
        echo -ne "  Services ready: ${GREEN}$running/$total${NC}\r"

        # Wait for NRF registrations to appear
        sleep 5
        nf_count=$(grep -c "NF registered" log/nrf.log 2>/dev/null || echo 0)

        if [ $nf_count -gt 0 ]; then
            echo -e "\n${GREEN}✓ Services stabilized with $nf_count NF registrations${NC}"
            break
        fi
    else
        echo -ne "  Waiting for services: $running/$total\r"
    fi

    sleep 2
    ((waited+=2))
done

if [ $waited -ge $max_wait ]; then
    echo -e "\n${YELLOW}⚠ Timeout waiting for full stabilization${NC}"
else
    sleep 5  # Extra wait for services to fully register
fi

# Step 5: Verify health
echo -e "\n${BLUE}[5/5] Verifying health status...${NC}"
sleep 2

# Run quick status check
./quick_status.sh
