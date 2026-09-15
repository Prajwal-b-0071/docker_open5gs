# Open5GS Health Check & Monitoring Tools

This document explains the health check and monitoring scripts created for the Open5GS 5G Core Network deployment.

## Quick Start

### View Current Health Status
```bash
cd /home/dtri/docker_open5gs
./quick_status.sh
```

This shows:
- ✓ Running containers (13/13 expected)
- ✓ NF registrations and status
- ✓ Core process health
- ✓ Connectivity between services
- ✓ Database status
- **Overall health assessment**: HEALTHY / OPERATIONAL / UNHEALTHY

### Full Detailed Health Check
```bash
./health_check.sh
```

Provides comprehensive monitoring including:
- Network function registration tracking
- Container and process status
- Error summary and analysis
- Service connectivity verification
- Network function endpoint details
- Overall system health rating

### Diagnose Issues
```bash
./diagnose.sh
```

Identifies and explains:
- Heartbeat failures and their causes
- HTTP/2 protocol errors
- UPF traffic issues
- Database connectivity
- DNS resolution status
- Port availability
- Specific recommendations for fixes

## Expected Health States

### ✓ HEALTHY
```
- All 13 services running (Up)
- All core processes active (NRF, AMF, SMF, UPF)
- Multiple NF registrations (>10)
- Low de-registration count
- Network connectivity OK
- Database connected
- Few or no errors
```

### ⚠ OPERATIONAL (WITH ISSUES)
```
- 12-13 services running
- Core processes active
- Some NF registrations
- Moderate de-registrations
- Network connectivity OK
- Some errors in logs
- System functional but degraded
```

### ✗ UNHEALTHY
```
- <12 services running
- Core processes down
- No NF registrations
- Network connectivity failed
- Many errors
- Database disconnected
```

## Understanding the Logs

### NRF Log (`log/nrf.log`)
Tracks Network Function registration lifecycle:
```
- "NF registered" - Service successfully registered with NRF
- "No heartbeat" - Service lost connection, de-registering
- "NFInstance associated" - NRF discovering new function
- "Setup NF EndPoint" - Service advertising its SBI endpoint
```

### AMF Log (`log/amf.log`)
Handles UE (User Equipment) connections and registration.

### SMF Log (`log/smf.log`)
Manages PDU sessions and data plane configuration.

### UPF Log (`log/upf.log`)
Forwards user traffic. "User Traffic Buffered" is normal when no UEs are connected.

## Common Issues and Solutions

### Issue: "No heartbeat" errors
**Cause**: NF loses connection to NRF due to timeout  
**Solution**: 
1. Check network connectivity: `./diagnose.sh`
2. Restart services: `./stabilize.sh`
3. Check if NRF is overloaded
4. Verify DNS resolution is working

### Issue: DNS resolution failures
**Cause**: Services can't resolve hostnames in Docker network  
**Solution**:
1. Services use Docker's internal DNS (127.0.0.11)
2. This is normal and expected
3. If services can't connect, check network isolation

### Issue: "HTTP/2 client magic byte" errors
**Cause**: Using HTTP/1.1 tools (curl) with HTTP/2 service  
**Solution**:
1. Use `curl --http2` flag
2. These errors don't affect service communication
3. Services communicate properly via HTTP/2

### Issue: "User Traffic Buffered" in UPF
**Cause**: UE traffic can't be forwarded (no active UEs)  
**Solution**:
1. This is normal during idle periods
2. Deploy a test UE to verify data plane
3. Use UERANSIM or srsRAN for RF simulation

## Stabilizing the System

To get a clean "HEALTHY" state:

```bash
./stabilize.sh
```

This script will:
1. Stop all services gracefully
2. Clear old log files  
3. Restart services
4. Wait for stabilization (30-60 seconds)
5. Verify final health status

## Monitoring Commands

### Watch NRF Registration in Real-time
```bash
tail -f log/nrf.log | grep "NF registered\|No heartbeat"
```

### Check Current NF Registration Count
```bash
grep "NF registered" log/nrf.log | wc -l
```

### Monitor All Errors
```bash
tail -f log/*.log | grep "ERROR"
```

### Check Service Logs
```bash
# Last 50 lines of NRF
tail -50 log/nrf.log

# Last 100 lines of AMF
tail -100 log/amf.log

# Follow SMF logs in real-time
tail -f log/smf.log
```

### Check Container Status
```bash
# All containers
docker compose -f sa-vonr-deploy.yaml ps

# Just core services
docker compose -f sa-vonr-deploy.yaml ps nrf amf smf upf

# Running processes inside a container
docker compose -f sa-vonr-deploy.yaml exec nrf ps aux | grep open5gs
```

## Integration with Monitoring Systems

### For Prometheus/Grafana
Services expose metrics on port 9091:
```bash
docker compose -f sa-vonr-deploy.yaml exec amf curl http://localhost:9091/metrics
```

### For Logging Systems
All logs are in `/home/dtri/docker_open5gs/log/`:
- `nrf.log` - NRF registration events
- `amf.log` - AMF UE handling
- `smf.log` - SMF session management  
- `upf.log` - UPF packet forwarding
- `udm.log`, `udr.log`, etc. - Other core services

### Health Check Endpoints
Services communicate via HTTP/2 SBI interface on port 7777.
For querying service status, use the provided scripts rather than direct REST calls.

## Performance Baseline

Expected performance with `sa-vonr-deploy.yaml`:

| Metric | Expected | Warning | Critical |
|--------|----------|---------|----------|
| Running Services | 13/13 | 12/13 | <12/13 |
| NRF Registrations | >10 | 1-10 | 0 |
| De-registrations | <50 | 50-200 | >200 |
| Error Count | <10 | 10-100 | >100 |
| CPU Usage | <20% | 20-50% | >50% |
| Memory Usage | <2GB | 2-4GB | >4GB |

## Troubleshooting Workflow

1. **Run quick status check**
   ```bash
   ./quick_status.sh
   ```
   - If HEALTHY: No action needed
   - If OPERATIONAL: Continue monitoring
   - If UNHEALTHY: Go to step 2

2. **Diagnose issues**
   ```bash
   ./diagnose.sh
   ```
   - Review recommendations
   - Check specific logs mentioned

3. **Check specific service logs**
   ```bash
   tail -100 log/nrf.log  # View registration issues
   tail -100 log/amf.log  # View UE handling issues
   ```

4. **Restart affected service** (if needed)
   ```bash
   docker compose -f sa-vonr-deploy.yaml restart nrf
   docker compose -f sa-vonr-deploy.yaml restart amf
   ```

5. **Full stabilization** (if multiple issues)
   ```bash
   ./stabilize.sh
   ```

6. **Verify recovery**
   ```bash
   ./quick_status.sh
   ```

## For Development/Testing

### Clearing logs for fresh test run
```bash
rm -f log/*.log
docker compose -f sa-vonr-deploy.yaml restart
sleep 10
./quick_status.sh
```

### Running health checks in a loop
```bash
watch -n 5 './quick_status.sh'  # Refresh every 5 seconds
```

### Automated health monitoring
```bash
while true; do
    clear
    ./quick_status.sh
    sleep 10
done
```

## Script Summary

| Script | Purpose | Usage |
|--------|---------|-------|
| `quick_status.sh` | Fast health overview (30 sec) | Daily status check |
| `health_check.sh` | Detailed health report (2 min) | Troubleshooting |
| `diagnose.sh` | Issue identification | Finding root causes |
| `stabilize.sh` | System reset & recovery | Restore healthy state |

## Contact & Support

For issues or improvements to these health check scripts:
- Review the comments in each script
- Check `./diagnose.sh` output for specific issues
- Review docker compose logs: `docker compose -f sa-vonr-deploy.yaml logs`
