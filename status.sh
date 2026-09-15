#!/bin/bash

###############################################################################
# Container Status Check - 5G Core + IMS
###############################################################################

cd /home/dtri/docker_open5gs

COMPOSE_FILE="sa-vonr-deploy.yaml"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    CORE NETWORK STATUS                        ║${NC}"
echo -e "${BLUE}║              $(date '+%Y-%m-%d %H:%M:%S')                               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${BLUE}5G CORE SERVICES:${NC}"
echo "─────────────────────────────────────────────────────────────────"

core_services=("nrf" "amf" "smf" "upf" "udm" "udr" "ausf" "nssf" "pcf" "bsf" "scp")
core_running=0
core_total=${#core_services[@]}

for service in "${core_services[@]}"; do
    status=$(docker compose -f $COMPOSE_FILE ps $service --format "{{.Status}}" 2>/dev/null)

    if [[ $status == "Up"* ]]; then
        echo -e "  ${GREEN}●${NC} $service - $status"
        ((core_running++))
    else
        echo -e "  ${RED}●${NC} $service - $status"
    fi
done

echo ""
echo -e "5G Core: ${GREEN}$core_running${NC} / $core_total services"

# IMS Services
echo -e "\n${BLUE}IMS SERVICES:${NC}"
echo "─────────────────────────────────────────────────────────────────"

ims_services=("icscf" "scscf" "pcscf" "pyhss" "rtpengine" "smsc" "osmomsc" "osmohlr" "ocs")
ims_running=0
ims_total=0

for service in "${ims_services[@]}"; do
    status=$(docker compose -f $COMPOSE_FILE ps $service --format "{{.Status}}" 2>/dev/null)

    if [ -z "$status" ]; then
        # Service not in this deployment
        continue
    fi

    ((ims_total++))

    if [[ $status == "Up"* ]]; then
        echo -e "  ${GREEN}●${NC} $service - $status"
        ((ims_running++))
    else
        echo -e "  ${RED}●${NC} $service - $status"
    fi
done

if [ $ims_total -gt 0 ]; then
    echo ""
    echo -e "IMS Services: ${GREEN}$ims_running${NC} / $ims_total services"
else
    echo -e "  (No IMS services in current deployment)"
fi

# Support Services
echo -e "\n${BLUE}SUPPORT SERVICES:${NC}"
echo "─────────────────────────────────────────────────────────────────"

support_services=("mongo" "mysql" "webui" "dns" "grafana" "metrics")
support_running=0
support_total=0

for service in "${support_services[@]}"; do
    status=$(docker compose -f $COMPOSE_FILE ps $service --format "{{.Status}}" 2>/dev/null)

    if [ -z "$status" ]; then
        continue
    fi

    ((support_total++))

    if [[ $status == "Up"* ]]; then
        echo -e "  ${GREEN}●${NC} $service - $status"
        ((support_running++))
    else
        echo -e "  ${RED}●${NC} $service - $status"
    fi
done

if [ $support_total -gt 0 ]; then
    echo ""
    echo -e "Support: ${GREEN}$support_running${NC} / $support_total services"
fi

# Total Summary
echo -e "\n${BLUE}SUMMARY:${NC}"
echo "─────────────────────────────────────────────────────────────────"

total_running=$((core_running + ims_running + support_running))
total_services=$((core_total + ims_total + support_total))

echo -e "Total: ${GREEN}$total_running${NC} / $total_services services running"

if [ $total_running -eq $total_services ]; then
    echo -e "Status: ${GREEN}✓ ALL HEALTHY${NC}"
elif [ $total_running -ge $((total_services - 2)) ]; then
    echo -e "Status: ${YELLOW}⚠ OPERATIONAL${NC}"
else
    echo -e "Status: ${RED}✗ DEGRADED${NC}"
fi

echo ""
