#!/bin/bash

###############################################################################
# Open5GS Network Health Check Script
# Monitors 5G Core Network health status
###############################################################################

cd /home/dtri/docker_open5gs

COMPOSE_FILE="sa-vonr-deploy.yaml"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if service is running
check_service_running() {
    local service=$1
    if docker compose -f $COMPOSE_FILE exec $service pgrep -f "open5gs" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Function to check container status
check_container_status() {
    local service=$1
    local status=$(docker compose -f $COMPOSE_FILE ps $service --format "{{.Status}}" 2>/dev/null)
    if [[ $status == "Up"* ]]; then
        echo -e "${GREEN}✓ $status${NC}"
        return 0
    else
        echo -e "${RED}✗ $status${NC}"
        return 1
    fi
}

# Function to get NF registration count from logs
get_nf_registration_count() {
    grep "NF registered" log/nrf.log 2>/dev/null | wc -l
}

# Function to get NF deregistration count
get_nf_deregistration_count() {
    grep "NF de-registered" log/nrf.log 2>/dev/null | wc -l
}

# Function to check service errors
check_service_errors() {
    local service=$1
    local logfile="log/${service}.log"
    if [ -f "$logfile" ]; then
        local errors=$(grep "ERROR" "$logfile" 2>/dev/null | wc -l)
        echo $errors
    else
        echo 0
    fi
}

# Function to get last error
get_last_error() {
    local service=$1
    local logfile="log/${service}.log"
    if [ -f "$logfile" ]; then
        grep "ERROR" "$logfile" 2>/dev/null | tail -1 | sed 's/.*ERROR: //'
    fi
}

# Main health check
clear
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Open5GS Core Network Health Check Status              ║${NC}"
echo -e "${BLUE}║     $(date '+%Y-%m-%d %H:%M:%S')                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"

# Network Function Registration Status
echo -e "\n${BLUE}[1] NETWORK FUNCTION REGISTRATION STATUS${NC}"
echo "─────────────────────────────────────────"

nf_reg=$(get_nf_registration_count)
nf_dereg=$(get_nf_deregistration_count)

echo -e "NFs Registered:     ${GREEN}$nf_reg${NC}"
echo -e "NFs De-registered:  ${YELLOW}$nf_dereg${NC}"

if [ $nf_reg -gt 0 ]; then
    echo -e "\nRegistered Functions (Last 10):"
    grep "NF registered" log/nrf.log 2>/dev/null | tail -10 | sed 's/.*\[nrf\] INFO: /   /'
fi

# Container Status
echo -e "\n${BLUE}[2] CONTAINER STATUS${NC}"
echo "─────────────────────────────────────────"

services=("nrf" "amf" "smf" "upf" "udm" "udr" "ausf" "nssf" "pcf" "bsf" "scp")
healthy_count=0

for service in "${services[@]}"; do
    printf "%-10s: " "$service"
    if check_container_status "$service"; then
        ((healthy_count++))
    fi
done

echo -e "\nRunning: $healthy_count/${#services[@]} services"

# Process Status
echo -e "\n${BLUE}[3] OPEN5GS PROCESS STATUS${NC}"
echo "─────────────────────────────────────────"

process_count=0
for service in "${services[@]}"; do
    printf "%-10s: " "$service"
    if check_service_running "$service"; then
        ((process_count++))
    fi
done

echo -e "\nRunning: $process_count/${#services[@]} processes"

# Error Summary
echo -e "\n${BLUE}[4] ERROR SUMMARY${NC}"
echo "─────────────────────────────────────────"

total_errors=0
for service in "${services[@]}"; do
    errors=$(check_service_errors "$service")
    if [ $errors -gt 0 ]; then
        printf "%-10s: ${RED}%d errors${NC}\n" "$service" "$errors"
        ((total_errors+=$errors))
    else
        printf "%-10s: ${GREEN}No errors${NC}\n" "$service"
    fi
done

# Recent Issues
echo -e "\n${BLUE}[5] RECENT ISSUES${NC}"
echo "─────────────────────────────────────────"

if [ $total_errors -gt 0 ]; then
    echo -e "${YELLOW}Found errors in logs:${NC}"
    grep "ERROR" log/*.log 2>/dev/null | tail -10 | sed 's/.*log:/   /'
else
    echo -e "${GREEN}No errors detected${NC}"
fi

# Service Connectivity
echo -e "\n${BLUE}[6] SERVICE CONNECTIVITY TEST${NC}"
echo "─────────────────────────────────────────"

connectivity_ok=0
for service in "amf" "smf" "upf"; do
    if docker compose -f $COMPOSE_FILE exec $service ping -c 1 nrf > /dev/null 2>&1; then
        echo -e "$service → nrf: ${GREEN}✓ Connected${NC}"
        ((connectivity_ok++))
    else
        echo -e "$service → nrf: ${RED}✗ Failed${NC}"
    fi
done

# Network Function Details
echo -e "\n${BLUE}[7] NETWORK FUNCTION DETAILS${NC}"
echo "─────────────────────────────────────────"

echo "AMF Endpoint:"
grep "\[AMF\] NFInstance associated" log/nrf.log 2>/dev/null | tail -1 | sed 's/.*\[sbi\] INFO: /   /'

echo -e "\nSMF Endpoint:"
grep "\[SMF\] NFInstance associated" log/nrf.log 2>/dev/null | tail -1 | sed 's/.*\[sbi\] INFO: /   /'

echo -e "\nUPF Endpoint:"
grep "\[UPF\] NFInstance associated" log/nrf.log 2>/dev/null | tail -1 | sed 's/.*\[sbi\] INFO: /   /'

# Overall Health Status
echo -e "\n${BLUE}[8] OVERALL HEALTH STATUS${NC}"
echo "─────────────────────────────────────────"

if [ $healthy_count -eq ${#services[@]} ] && [ $total_errors -eq 0 ] && [ $connectivity_ok -eq 3 ]; then
    echo -e "${GREEN}✓ ALL SYSTEMS HEALTHY${NC}"
    exit 0
elif [ $healthy_count -ge $((${#services[@]} - 2)) ] && [ $connectivity_ok -ge 2 ]; then
    echo -e "${YELLOW}⚠ PARTIALLY HEALTHY (Some services degraded)${NC}"
    exit 1
else
    echo -e "${RED}✗ CRITICAL - MULTIPLE FAILURES DETECTED${NC}"
    exit 2
fi
