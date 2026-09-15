#!/bin/bash

###############################################################################
# Quick Status Check - Simple health overview
###############################################################################

cd /home/dtri/docker_open5gs

COMPOSE_FILE="sa-vonr-deploy.yaml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              OPEN5GS CORE NETWORK STATUS                      ║${NC}"
echo -e "${BLUE}║              $(date '+%Y-%m-%d %H:%M:%S')                               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

# Get current state
echo -e "\n${BLUE}CONTAINER STATUS:${NC}"
echo "─────────────────────────────────────────────────────────────────"

services=("nrf" "amf" "smf" "upf" "udm" "udr" "ausf" "nssf" "pcf" "bsf" "scp" "mongo" "webui")
running=0
total=${#services[@]}

for service in "${services[@]}"; do
    status=$(docker compose -f $COMPOSE_FILE ps $service --format "{{.Status}}" 2>/dev/null)

    if [[ $status == "Up"* ]]; then
        echo -e "  ${GREEN}●${NC} $service - $status"
        ((running++))
    else
        echo -e "  ${RED}●${NC} $service - $status"
    fi
done

echo ""
echo -e "Running: ${GREEN}$running${NC} / $total services"

# Network Function Registration
echo -e "\n${BLUE}NETWORK FUNCTION REGISTRATION:${NC}"
echo "─────────────────────────────────────────────────────────────────"

nf_reg=$(grep "NF registered" log/nrf.log 2>/dev/null | tail -1 | sed 's/.*\[//; s/\].*//')
nf_total=$(grep "NF registered" log/nrf.log 2>/dev/null | wc -l)
nf_dereg=$(grep "NF de-registered" log/nrf.log 2>/dev/null | wc -l)

if [ $nf_total -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Total registrations: $nf_total"
else
    echo -e "  ${RED}✗${NC} No registrations found"
fi

echo -e "  ${YELLOW}⚠${NC} De-registrations: $nf_dereg"

# Process Health
echo -e "\n${BLUE}CORE SERVICES RUNNING:${NC}"
echo "─────────────────────────────────────────────────────────────────"

for service in nrf amf smf upf; do
    if docker compose -f $COMPOSE_FILE exec $service pgrep -f "open5gs" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $service process active"
    else
        echo -e "  ${RED}✗${NC} $service process stopped"
    fi
done

# Error Status
echo -e "\n${BLUE}ERROR STATUS:${NC}"
echo "─────────────────────────────────────────────────────────────────"

errors=$(grep "ERROR" log/*.log 2>/dev/null | wc -l)
if [ $errors -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} No errors detected"
else
    echo -e "  ${YELLOW}⚠${NC} $errors error messages in logs"
    echo -e "    (Run './diagnose.sh' for details)"
fi

# Connectivity
echo -e "\n${BLUE}INTER-SERVICE CONNECTIVITY:${NC}"
echo "─────────────────────────────────────────────────────────────────"

if docker compose -f $COMPOSE_FILE exec amf ping -c 1 nrf > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} AMF ↔ NRF connected"
else
    echo -e "  ${RED}✗${NC} AMF ↔ NRF unreachable"
fi

if docker compose -f $COMPOSE_FILE exec smf ping -c 1 nrf > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} SMF ↔ NRF connected"
else
    echo -e "  ${RED}✗${NC} SMF ↔ NRF unreachable"
fi

# Database
echo -e "\n${BLUE}DATABASE STATUS:${NC}"
echo "─────────────────────────────────────────────────────────────────"

if docker compose -f $COMPOSE_FILE exec mongo mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} MongoDB connected"
else
    echo -e "  ${RED}✗${NC} MongoDB unreachable"
fi

# Overall Health Summary
echo -e "\n${BLUE}OVERALL HEALTH ASSESSMENT:${NC}"
echo "─────────────────────────────────────────────────────────────────"

if [ $running -eq $total ] && [ $nf_total -gt 0 ] && [ $errors -lt 100 ]; then
    echo -e "${GREEN}✓ SYSTEM HEALTHY${NC}"
    echo ""
    echo "All core services are running and registered with NRF."
    echo "Network is ready for testing."
    exit 0
elif [ $running -ge $((total - 2)) ]; then
    echo -e "${YELLOW}⚠ SYSTEM OPERATIONAL (WITH ISSUES)${NC}"
    echo ""
    echo "Most services are running but some degradation detected."
    echo "System is functional but may have limited capacity."
    exit 1
else
    echo -e "${RED}✗ SYSTEM UNHEALTHY${NC}"
    echo ""
    echo "Multiple services are down or not responding."
    echo "Run './diagnose.sh' for detailed troubleshooting."
    exit 2
fi
