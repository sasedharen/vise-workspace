#!/bin/bash

# GitLab Runner Setup Script for VISE Project
# This script configures multiple GitLab runners for optimal performance with 500 developers

set -e

# Configuration
GITLAB_URL="http://gitlab.vise.local"
RUNNER_CONFIG_DIR="./runner-configs"
REGISTRATION_TOKEN="${GITLAB_REGISTRATION_TOKEN:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    if [[ -z "$REGISTRATION_TOKEN" ]]; then
        log_warn "GITLAB_REGISTRATION_TOKEN environment variable not set."
        log_info "You can find the registration token in GitLab Admin Area > Runners"
        read -p "Please enter the registration token: " REGISTRATION_TOKEN
    fi
    
    log_info "Prerequisites check completed."
}

# Create runner directories
create_runner_directories() {
    log_info "Creating runner directories..."
    
    for i in {1..3}; do
        mkdir -p "./runner-config-$i"
        mkdir -p "./cache/runner-$i"
    done
    
    mkdir -p "./logs/runners"
    log_info "Runner directories created."
}

# Register runners
register_runners() {
    log_info "Registering GitLab runners..."
    
    # Runner configurations
    declare -A runners=(
        ["1"]="docker-runner-shared"
        ["2"]="go-backend-runner" 
        ["3"]="react-frontend-runner"
    )
    
    for runner_id in "${!runners[@]}"; do
        runner_name="${runners[$runner_id]}"
        config_dir="./runner-config-$runner_id"
        
        log_info "Registering runner: $runner_name"
        
        # Register the runner
        docker run --rm \
            -v "$PWD/$config_dir:/etc/gitlab-runner" \
            gitlab/gitlab-runner:v16.8.1 register \
            --non-interactive \
            --url="$GITLAB_URL" \
            --registration-token="$REGISTRATION_TOKEN" \
            --executor="docker" \
            --docker-image="alpine:3.19" \
            --description="$runner_name" \
            --tag-list="docker,$runner_name" \
            --run-untagged="true" \
            --locked="false" \
            --docker-privileged="true" \
            --docker-volumes="/var/run/docker.sock:/var/run/docker.sock" \
            --docker-volumes="/cache" \
            --docker-volumes="/builds:/builds:rw"
        
        if [[ $? -eq 0 ]]; then
            log_info "Successfully registered runner: $runner_name"
        else
            log_error "Failed to register runner: $runner_name"
            exit 1
        fi
    done
}

# Configure runner performance settings
configure_runner_performance() {
    log_info "Configuring runner performance settings..."
    
    for i in {1..3}; do
        config_file="./runner-config-$i/config.toml"
        
        if [[ -f "$config_file" ]]; then
            # Update concurrent jobs
            sed -i.bak 's/concurrent = 1/concurrent = 10/' "$config_file"
            
            # Add cache configuration
            cat >> "$config_file" << EOF

  [runners.cache]
    Type = "local"
    Path = "/cache"
    Shared = true
    
    [runners.cache.local]
      MaxUploadedArchiveSize = 1073741824  # 1GB
EOF
            
            log_info "Updated configuration for runner-$i"
        else
            log_warn "Configuration file not found for runner-$i"
        fi
    done
}

# Create monitoring script
create_monitoring_script() {
    log_info "Creating monitoring script..."
    
    cat > "./scripts/monitor-runners.sh" << 'EOF'
#!/bin/bash

# GitLab Runner Monitoring Script

check_runner_health() {
    echo "=== GitLab Runner Health Check ==="
    echo "Timestamp: $(date)"
    echo
    
    # Check runner containers
    echo "Runner Container Status:"
    docker ps --filter "name=gitlab-runner" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo
    
    # Check runner logs for errors
    echo "Recent Runner Errors (last 10):"
    docker logs gitlab-runner-1 2>&1 | grep -i error | tail -10
    echo
    
    # Check system resources
    echo "System Resources:"
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')"
    echo "Memory Usage: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
    echo "Disk Usage: $(df -h / | awk 'NR==2{print $5}')"
    echo
    
    # Check concurrent jobs
    echo "Active Jobs:"
    docker exec gitlab-runner-1 gitlab-runner list 2>/dev/null || echo "Could not fetch runner status"
}

# Run health check
check_runner_health

# Schedule this script to run every 5 minutes with cron:
# */5 * * * * /path/to/monitor-runners.sh >> /var/log/gitlab-runner-health.log 2>&1
EOF
    
    chmod +x "./scripts/monitor-runners.sh"
    log_info "Monitoring script created at ./scripts/monitor-runners.sh"
}

# Create backup script
create_backup_script() {
    log_info "Creating backup script..."
    
    cat > "./scripts/backup-runners.sh" << 'EOF'
#!/bin/bash

# GitLab Runner Backup Script

BACKUP_DIR="./backups/runners"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup runner configurations
echo "Backing up runner configurations..."
for i in {1..3}; do
    if [[ -d "./runner-config-$i" ]]; then
        tar -czf "$BACKUP_DIR/runner-config-$i-$TIMESTAMP.tar.gz" "./runner-config-$i"
        echo "Backed up runner-config-$i"
    fi
done

# Backup runner logs
echo "Backing up runner logs..."
mkdir -p "$BACKUP_DIR/logs"
docker logs gitlab-runner-1 > "$BACKUP_DIR/logs/runner-1-$TIMESTAMP.log" 2>&1
docker logs gitlab-runner-2 > "$BACKUP_DIR/logs/runner-2-$TIMESTAMP.log" 2>&1
docker logs gitlab-runner-3 > "$BACKUP_DIR/logs/runner-3-$TIMESTAMP.log" 2>&1

# Cleanup old backups (keep last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR/logs" -name "*.log" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
EOF
    
    chmod +x "./scripts/backup-runners.sh"
    log_info "Backup script created at ./scripts/backup-runners.sh"
}

# Main execution
main() {
    log_info "Starting GitLab Runner setup for VISE project..."
    
    check_prerequisites
    create_runner_directories
    
    # Create scripts directory
    mkdir -p "./scripts"
    
    register_runners
    configure_runner_performance
    create_monitoring_script
    create_backup_script
    
    log_info "GitLab Runner setup completed successfully!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Start the runners: docker-compose -f docker-compose.gitlab.yml up -d"
    log_info "2. Monitor runners: ./scripts/monitor-runners.sh"
    log_info "3. Setup periodic monitoring with cron"
    log_info "4. Configure your .gitlab-ci.yml files in your repositories"
    log_info ""
    log_info "Runner URLs:"
    log_info "- GitLab: http://gitlab.vise.local"
    log_info "- Registry: http://gitlab.vise.local:5050"
    log_info "- Health Check: http://health.vise.local/health"
}

# Execute main function
main "$@"