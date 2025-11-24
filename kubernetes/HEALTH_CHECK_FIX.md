# Health Check Fix for Jenkinsfile

## Problem
The health check is failing because it's trying to use `jq` to parse JSON, but the service might not be responding with valid JSON or might not be running yet.

## Solution
Replace the health check logic in the "Verify Docker Deployment" stage with this more robust version:

```groovy
# Check config-server
echo "Checking config-server..."
HEALTH_RESPONSE=$(ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -s http://localhost:8888/actuator/health 2>/dev/null || echo 'CONNECTION_FAILED'")
if echo "$HEALTH_RESPONSE" | grep -q "CONNECTION_FAILED"; then
    echo "ERROR: Cannot connect to config-server on port 8888"
    echo "Service may not be running yet. Check: ssh ${SSH_USER}@${REMOTE_IP} 'docker ps | grep config'"
    exit 1
elif echo "$HEALTH_RESPONSE" | grep -q '"status":"UP"'; then
    echo "✓ config-server is UP"
else
    echo "ERROR: config-server is not healthy"
    echo "Response: $HEALTH_RESPONSE"
    exit 1
fi

# Check discovery-server
echo "Checking discovery-server..."
HEALTH_RESPONSE=$(ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -s http://localhost:8761/actuator/health 2>/dev/null || echo 'CONNECTION_FAILED'")
if echo "$HEALTH_RESPONSE" | grep -q "CONNECTION_FAILED"; then
    echo "ERROR: Cannot connect to discovery-server on port 8761"
    exit 1
elif echo "$HEALTH_RESPONSE" | grep -q '"status":"UP"'; then
    echo "✓ discovery-server is UP"
else
    echo "ERROR: discovery-server is not healthy"
    echo "Response: $HEALTH_RESPONSE"
    exit 1
fi

# Check api-gateway
echo "Checking api-gateway..."
HEALTH_RESPONSE=$(ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -s http://localhost:8080/actuator/health 2>/dev/null || echo 'CONNECTION_FAILED'")
if echo "$HEALTH_RESPONSE" | grep -q "CONNECTION_FAILED"; then
    echo "ERROR: Cannot connect to api-gateway on port 8080"
    exit 1
elif echo "$HEALTH_RESPONSE" | grep -q '"status":"UP"'; then
    echo "✓ api-gateway is UP"
else
    echo "ERROR: api-gateway is not healthy"
    echo "Response: $HEALTH_RESPONSE"
    exit 1
fi
```

## What Changed

### Before (using jq):
```bash
ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8888/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP"
```

**Problems:**
- Requires `jq` to be installed
- Fails if service returns non-JSON
- Doesn't show what the actual response was
- Hard to debug

### After (using grep):
```bash
HEALTH_RESPONSE=$(ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -s http://localhost:8888/actuator/health 2>/dev/null || echo 'CONNECTION_FAILED'")
if echo "$HEALTH_RESPONSE" | grep -q '"status":"UP"'; then
    echo "✓ config-server is UP"
else
    echo "Response: $HEALTH_RESPONSE"
    exit 1
fi
```

**Benefits:**
- No `jq` dependency
- Shows actual response for debugging
- Handles connection failures gracefully
- Clear error messages

## How to Apply

1. Open your Jenkinsfile
2. Find the "Verify Docker Deployment" stage (around line 398)
3. Replace the health check sections (lines 424-446) with the new code above
4. Save and test

## Testing

After applying the fix, the output will be:

```
=== Verifying service health endpoints ===
Checking config-server...
✓ config-server is UP
Checking discovery-server...
✓ discovery-server is UP
Checking api-gateway...
✓ api-gateway is UP
```

Or if there's an error:
```
Checking config-server...
ERROR: Cannot connect to config-server on port 8888
Service may not be running yet. Check: ssh ec2-user@54.696.78.18 'docker ps | grep config'
```

This gives you much better debugging information!
