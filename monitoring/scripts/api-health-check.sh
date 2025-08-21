#!/bin/bash

# VISE API Health Check Script
# Monitors OPA, Redis, and VISE Backend API endpoints
# Exports metrics to Prometheus format

METRICS_FILE="/tmp/vise_api_metrics.prom"
TIMESTAMP=$(date +%s)

# API Endpoints to monitor
OPA_URL="http://localhost:8181"
REDIS_URL="http://localhost:9121"
VISE_BACKEND_URL="http://localhost:6000"

# Initialize metrics file
cat > "$METRICS_FILE" << EOF
# HELP vise_api_up Whether the API endpoint is up (1) or down (0)
# TYPE vise_api_up gauge
# HELP vise_api_response_time Response time in milliseconds
# TYPE vise_api_response_time gauge
# HELP vise_api_check_timestamp Last health check timestamp
# TYPE vise_api_check_timestamp gauge
EOF

# Function to check endpoint health
check_endpoint() {
    local name="$1"
    local url="$2"
    local endpoint="$3"
    local expected_status="${4:-200}"
    
    echo "Checking $name at $url$endpoint"
    
    start_time=$(date +%s%3N)
    response=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 "$url$endpoint" 2>/dev/null)
    end_time=$(date +%s%3N)
    
    response_time=$((end_time - start_time))
    
    if [ "$response" = "$expected_status" ]; then
        status=1
        echo "$name is UP (${response_time}ms)"
    else
        status=0
        echo "$name is DOWN (HTTP: $response)"
    fi
    
    # Export metrics
    echo "vise_api_up{service=\"$name\",endpoint=\"$endpoint\"} $status" >> "$METRICS_FILE"
    echo "vise_api_response_time{service=\"$name\",endpoint=\"$endpoint\"} $response_time" >> "$METRICS_FILE"
}

# Check OPA endpoints
check_endpoint "opa" "$OPA_URL" "/health" "200"
check_endpoint "opa_data" "$OPA_URL" "/v1/data" "200"
check_endpoint "opa_policies" "$OPA_URL" "/v1/policies" "200"

# Check Redis (via exporter)
check_endpoint "redis" "$REDIS_URL" "/metrics" "200"

# Check VISE Backend API endpoints
check_endpoint "vise_health" "$VISE_BACKEND_URL" "/health" "200"
check_endpoint "vise_auth_health" "$VISE_BACKEND_URL" "/api/v1/auth/health" "200"
check_endpoint "vise_lookup_health" "$VISE_BACKEND_URL" "/api/v1/lookup/health" "200"

# VISE Backend Auth Endpoints
check_endpoint "auth_login" "$VISE_BACKEND_URL" "/api/v1/auth/login" "405"  # Method not allowed for GET
check_endpoint "auth_register" "$VISE_BACKEND_URL" "/api/v1/auth/register" "405"
check_endpoint "auth_refresh" "$VISE_BACKEND_URL" "/api/v1/auth/refresh" "405"

# VISE Backend Admission Endpoints
check_endpoint "admissions_draft" "$VISE_BACKEND_URL" "/api/v1/admissions/draft" "405"  # POST only
check_endpoint "admissions_submit" "$VISE_BACKEND_URL" "/api/v1/admissions/submit" "405"

# VISE Backend Lookup Endpoints
check_endpoint "lookup_all" "$VISE_BACKEND_URL" "/api/v1/lookup/all" "200"
check_endpoint "lookup_geographic" "$VISE_BACKEND_URL" "/api/v1/lookup/geographic" "200"
check_endpoint "lookup_institutions" "$VISE_BACKEND_URL" "/api/v1/lookup/institutions" "200"
check_endpoint "lookup_branches" "$VISE_BACKEND_URL" "/api/v1/lookup/branches" "200"
check_endpoint "lookup_curriculum" "$VISE_BACKEND_URL" "/api/v1/lookup/curriculum" "200"

# VISE Backend Admin Endpoints (expect auth failure)
check_endpoint "admin_pending" "$VISE_BACKEND_URL" "/api/v1/admin/pending-verifications" "401"  # Unauthorized
check_endpoint "admin_verify" "$VISE_BACKEND_URL" "/api/v1/admin/verify-document" "401"

# Add timestamp
echo "vise_api_check_timestamp $TIMESTAMP" >> "$METRICS_FILE"

# Move metrics to location accessible by node-exporter textfile collector
mkdir -p /tmp/node-exporter-textfile
cp "$METRICS_FILE" /tmp/node-exporter-textfile/vise_api_metrics.prom

echo "Health check completed at $(date)"
echo "Metrics exported to $METRICS_FILE"