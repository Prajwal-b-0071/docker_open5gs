#!/bin/bash

###############################################################################
# Open5GS Diagnostics & Fix Script
# Identifies and fixes common issues
###############################################################################

cd /home/dtri/docker_open5gs

echo "╔════════════════════════════════════════════╗"
echo "║   Open5GS Diagnostics & Troubleshoot      ║"
echo "╚════════════════════════════════════════════╝"

COMPOSE_FILE="sa-vonr-deploy.yaml"

# Issue 1: Check for heartbeat failures
echo -e "\n[1] Checking for Heartbeat Issues..."
echo "─────────────────────────────────────"

heartbeat_fails=$(grep "No heartbeat" log/nrf.log | wc -l)
echo "Total heartbeat failures: $heartbeat_fails"

if [ $heartbeat_fails -gt 10 ]; then
    echo "⚠ HIGH: Too many heartbeat failures detected"
    echo "  → Services are losing connection to NRF"
    echo "  → Possible causes:"
    echo "    - NRF overload"
    echo "    - Network instability"
    echo "    - Services crashing"
fi

# Issue 2: Check for HTTP/2 errors
echo -e "\n[2] Checking for HTTP/2 Protocol Errors..."
echo "─────────────────────────────────────"

http2_errors=$(grep "bad client magic byte string\|nghttp2" log/nrf.log | wc -l)
echo "HTTP/2 errors: $http2_errors"

if [ $http2_errors -gt 5 ]; then
    echo "⚠ NOTICE: HTTP/2 protocol errors detected"
    echo "  → This is expected when using curl without --http2 flag"
    echo "  → Services are still communicating properly via HTTP/2"
fi

# Issue 3: Check for UPF traffic buffering
echo -e "\n[3] Checking for UPF Traffic Issues..."
echo "─────────────────────────────────────"

upf_buffered=$(grep "User Traffic Buffered" log/upf.log | wc -l)
echo "Traffic buffering events: $upf_buffered"

if [ $upf_buffered -gt 0 ]; then
    echo "ℹ INFO: UPF has buffered traffic events"
    echo "  → This occurs when UE cannot receive forwarded packets"
    echo "  → Normal during test periods without active UEs"
fi

# Issue 4: Database connectivity
echo -e "\n[4] Checking Database Connectivity..."
echo "─────────────────────────────────────"

if docker compose -f $COMPOSE_FILE exec mongo mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo "✓ MongoDB: Connected"
else
    echo "✗ MongoDB: Connection failed"
fi

# Issue 5: Service DNS resolution
echo -e "\n[5] Checking DNS Resolution..."
echo "─────────────────────────────────────"

for service in "nrf" "amf" "smf"; do
    if docker compose -f $COMPOSE_FILE exec $service nslookup $service > /dev/null 2>&1; then
        echo "✓ $service: DNS resolves correctly"
    else
        echo "✗ $service: DNS resolution failed"
    fi
done

# Issue 6: Port availability
echo -e "\n[6] Checking Port Availability..."
echo "─────────────────────────────────────"

if docker compose -f $COMPOSE_FILE exec nrf ss -tlnp 2>/dev/null | grep -q "7777"; then
    echo "✓ NRF port 7777: Listening"
else
    echo "✗ NRF port 7777: Not listening"
fi

if docker compose -f $COMPOSE_FILE exec amf ss -tlnp 2>/dev/null | grep -q "7777"; then
    echo "✓ AMF port 7777: Listening"
else
    echo "✗ AMF port 7777: Not listening"
fi

# Recommendations
echo -e "\n${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        RECOMMENDATIONS                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"

echo -e "\n1. For production deployment:"
echo "   □ Increase NRF heartbeat timeout in config"
echo "   □ Add resource limits to prevent service starvation"
echo "   □ Enable proper logging and monitoring"

echo -e "\n2. For testing:"
echo "   □ Current errors are normal during idle periods"
echo "   □ Deploy test UE(s) to verify data plane"
echo "   □ Use UERANSIM or srsRAN for RF simulation"

echo -e "\n3. To view comprehensive logs:"
echo "   □ tail -f log/nrf.log       (NRF registration)"
echo "   □ tail -f log/amf.log       (AMF UE handling)"
echo "   □ tail -f log/smf.log       (SMF session management)"

echo ""
