#!/bin/bash

# GitLab CI/CD Metrics Collection Script
# Collects custom metrics for 500 developer environment

set -e

# Configuration
GITLAB_URL="${GITLAB_URL:-http://gitlab}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
METRICS_FILE="/tmp/gitlab_custom_metrics.prom"
LOG_FILE="/var/log/metrics-collector.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# Check if GitLab is accessible
check_gitlab_health() {
    if curl -f -s "$GITLAB_URL/health" >/dev/null 2>&1; then
        echo "gitlab_health_status 1" >> "$METRICS_FILE"
        return 0
    else
        echo "gitlab_health_status 0" >> "$METRICS_FILE"
        return 1
    fi
}

# Collect GitLab API metrics
collect_gitlab_metrics() {
    if [[ -z "$GITLAB_TOKEN" ]]; then
        log "Warning: GITLAB_TOKEN not set, skipping API metrics"
        return
    fi

    log "Collecting GitLab API metrics..."

    # Projects count
    projects_count=$(curl -s -H "Authorization: Bearer $GITLAB_TOKEN" \
        "$GITLAB_URL/api/v4/projects?statistics=true&per_page=1" \
        | jq -r '.[0].statistics.repository_size // 0' 2>/dev/null || echo "0")
    echo "gitlab_projects_total $projects_count" >> "$METRICS_FILE"

    # Users count
    users_count=$(curl -s -H "Authorization: Bearer $GITLAB_TOKEN" \
        "$GITLAB_URL/api/v4/users?per_page=1" \
        -I | grep -i "x-total:" | awk '{print $2}' || echo "0")
    echo "gitlab_users_total $users_count" >> "$METRICS_FILE"

    # Active runners
    runners_count=$(curl -s -H "Authorization: Bearer $GITLAB_TOKEN" \
        "$GITLAB_URL/api/v4/runners?status=active&per_page=100" \
        | jq '. | length' 2>/dev/null || echo "0")
    echo "gitlab_active_runners_total $runners_count" >> "$METRICS_FILE"

    # Recent pipelines (last 24 hours)
    yesterday=$(date -d "yesterday" '+%Y-%m-%d')
    pipelines_today=$(curl -s -H "Authorization: Bearer $GITLAB_TOKEN" \
        "$GITLAB_URL/api/v4/pipelines?updated_after=${yesterday}T00:00:00Z&per_page=100" \
        | jq '. | length' 2>/dev/null || echo "0")
    echo "gitlab_pipelines_24h_total $pipelines_today" >> "$METRICS_FILE"

    # Failed pipelines in last 24h
    failed_pipelines=$(curl -s -H "Authorization: Bearer $GITLAB_TOKEN" \
        "$GITLAB_URL/api/v4/pipelines?status=failed&updated_after=${yesterday}T00:00:00Z&per_page=100" \
        | jq '. | length' 2>/dev/null || echo "0")
    echo "gitlab_failed_pipelines_24h_total $failed_pipelines" >> "$METRICS_FILE"
}

# Collect Docker metrics
collect_docker_metrics() {
    log "Collecting Docker metrics..."

    # GitLab container stats
    if docker ps --format "table {{.Names}}" | grep -q "gitlab-ce"; then
        # GitLab container CPU
        gitlab_cpu=$(docker stats gitlab-ce --no-stream --format "{{.CPUPerc}}" | sed 's/%//' || echo "0")
        echo "gitlab_container_cpu_percent $gitlab_cpu" >> "$METRICS_FILE"

        # GitLab container memory
        gitlab_mem=$(docker stats gitlab-ce --no-stream --format "{{.MemUsage}}" | awk '{print $1}' | sed 's/MiB//' || echo "0")
        echo "gitlab_container_memory_mb $gitlab_mem" >> "$METRICS_FILE"
    fi

    # Runner containers stats
    for i in {1..3}; do
        runner_name="gitlab-runner-$i"
        if docker ps --format "table {{.Names}}" | grep -q "$runner_name"; then
            runner_cpu=$(docker stats "$runner_name" --no-stream --format "{{.CPUPerc}}" | sed 's/%//' || echo "0")
            runner_mem=$(docker stats "$runner_name" --no-stream --format "{{.MemUsage}}" | awk '{print $1}' | sed 's/MiB//' || echo "0")
            
            echo "gitlab_runner_cpu_percent{runner=\"$runner_name\"} $runner_cpu" >> "$METRICS_FILE"
            echo "gitlab_runner_memory_mb{runner=\"$runner_name\"} $runner_mem" >> "$METRICS_FILE"
        fi
    done

    # Total containers running
    containers_running=$(docker ps --quiet | wc -l)
    echo "docker_containers_running_total $containers_running" >> "$METRICS_FILE"

    # Docker system usage
    docker_images=$(docker images --quiet | wc -l)
    echo "docker_images_total $docker_images" >> "$METRICS_FILE"

    # Docker volumes
    docker_volumes=$(docker volume ls --quiet | wc -l)
    echo "docker_volumes_total $docker_volumes" >> "$METRICS_FILE"
}

# Collect GitLab Runner job metrics
collect_runner_metrics() {
    log "Collecting GitLab Runner metrics..."

    for i in {1..3}; do
        runner_name="gitlab-runner-$i"
        if docker ps --format "table {{.Names}}" | grep -q "$runner_name"; then
            # Check runner logs for job information
            running_jobs=$(docker logs "$runner_name" --tail 100 2>/dev/null | grep -c "Job succeeded\|Job failed" || echo "0")
            echo "gitlab_runner_completed_jobs_total{runner=\"$runner_name\"} $running_jobs" >> "$METRICS_FILE"

            # Check for errors in logs
            error_count=$(docker logs "$runner_name" --tail 100 2>/dev/null | grep -c "ERROR" || echo "0")
            echo "gitlab_runner_errors_total{runner=\"$runner_name\"} $error_count" >> "$METRICS_FILE"
        fi
    done
}

# Collect system performance metrics
collect_system_metrics() {
    log "Collecting system performance metrics..."

    # Load average
    load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | tr -d ' ')
    echo "system_load_1min $load_1min" >> "$METRICS_FILE"

    # Memory usage
    mem_total=$(free -m | awk '/^Mem:/{print $2}')
    mem_used=$(free -m | awk '/^Mem:/{print $3}')
    mem_percent=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc)
    echo "system_memory_usage_percent $mem_percent" >> "$METRICS_FILE"

    # Disk usage for critical paths
    gitlab_data_usage=$(df -h /var/opt/gitlab 2>/dev/null | awk 'NR==2{print $5}' | sed 's/%//' || echo "0")
    echo "gitlab_data_disk_usage_percent $gitlab_data_usage" >> "$METRICS_FILE"

    docker_usage=$(df -h /var/lib/docker 2>/dev/null | awk 'NR==2{print $5}' | sed 's/%//' || echo "0")
    echo "docker_disk_usage_percent $docker_usage" >> "$METRICS_FILE"

    # Network connections
    tcp_connections=$(ss -tun | wc -l)
    echo "system_tcp_connections_total $tcp_connections" >> "$METRICS_FILE"
}

# Collect CI/CD pipeline performance metrics
collect_pipeline_metrics() {
    log "Collecting pipeline performance metrics..."

    # Check for pipeline artifacts
    if [[ -d "/var/opt/gitlab/gitlab-rails/shared/artifacts" ]]; then
        artifacts_size=$(du -sm /var/opt/gitlab/gitlab-rails/shared/artifacts 2>/dev/null | awk '{print $1}' || echo "0")
        echo "gitlab_artifacts_size_mb $artifacts_size" >> "$METRICS_FILE"
    fi

    # Check for LFS objects
    if [[ -d "/var/opt/gitlab/git-data/repositories" ]]; then
        repo_size=$(du -sm /var/opt/gitlab/git-data/repositories 2>/dev/null | awk '{print $1}' || echo "0")
        echo "gitlab_repositories_size_mb $repo_size" >> "$METRICS_FILE"
    fi

    # Cache directory size
    if [[ -d "/cache" ]]; then
        cache_size=$(du -sm /cache 2>/dev/null | awk '{print $1}' || echo "0")
        echo "gitlab_cache_size_mb $cache_size" >> "$METRICS_FILE"
    fi
}

# Generate performance summary for 500 developers
generate_performance_summary() {
    log "Generating performance summary for 500 developers..."

    # Expected metrics for 500 developers
    expected_pipelines_per_hour=50
    expected_max_concurrent_jobs=100
    expected_avg_build_time_minutes=15

    # Current performance indicators
    current_hour=$(date +%H)
    
    # Estimate developer activity (higher during business hours)
    if [[ $current_hour -ge 8 && $current_hour -le 18 ]]; then
        activity_multiplier=1.0
    else
        activity_multiplier=0.3
    fi

    expected_current_load=$(echo "scale=0; $expected_pipelines_per_hour * $activity_multiplier" | bc)
    echo "gitlab_expected_pipeline_load_current_hour $expected_current_load" >> "$METRICS_FILE"

    # Resource recommendation based on current load
    current_runners=$(docker ps --format "table {{.Names}}" | grep -c "gitlab-runner" || echo "0")
    echo "gitlab_current_active_runners $current_runners" >> "$METRICS_FILE"

    recommended_runners=$(echo "scale=0; $expected_current_load / 10" | bc)
    if [[ $recommended_runners -lt 3 ]]; then
        recommended_runners=3
    fi
    echo "gitlab_recommended_runners $recommended_runners" >> "$METRICS_FILE"
}

# Main execution
main() {
    log "Starting metrics collection..."
    
    # Initialize metrics file
    cat > "$METRICS_FILE" << EOF
# HELP gitlab_custom_metrics Custom GitLab CI/CD metrics for 500 developers
# TYPE gitlab_custom_metrics gauge
EOF

    # Collect all metrics
    check_gitlab_health
    collect_gitlab_metrics
    collect_docker_metrics
    collect_runner_metrics
    collect_system_metrics
    collect_pipeline_metrics
    generate_performance_summary

    # Add timestamp
    echo "gitlab_metrics_last_updated $(date +%s)" >> "$METRICS_FILE"

    # Copy metrics to Prometheus textfile directory (if it exists)
    if [[ -d "/var/lib/node_exporter/textfile_collector" ]]; then
        cp "$METRICS_FILE" "/var/lib/node_exporter/textfile_collector/gitlab_custom.prom"
    fi

    log "Metrics collection completed. Metrics written to $METRICS_FILE"
    
    # Show summary
    echo "=== Metrics Collection Summary ==="
    echo "Timestamp: $(date)"
    echo "Metrics file: $METRICS_FILE"
    echo "Metrics count: $(grep -c '^gitlab_\|^docker_\|^system_' "$METRICS_FILE")"
    echo "=================================="
}

# Run main function
main "$@"