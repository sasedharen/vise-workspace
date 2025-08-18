# VISE CI/CD Deployment Guide

## Complete Setup Instructions for Production Environment

This guide provides step-by-step instructions for deploying the GitLab CE CI/CD pipeline in a production environment supporting 500 developers.

## 📋 Pre-Deployment Checklist

### Infrastructure Requirements ✅
- [ ] **Server Hardware**: 16+ cores, 32GB+ RAM, 1TB+ NVMe SSD
- [ ] **Network**: 1Gbps connection, static IP address
- [ ] **Operating System**: Ubuntu 22.04 LTS or CentOS 8+
- [ ] **Docker**: Version 24.0+ installed
- [ ] **Docker Compose**: Version 2.0+ installed
- [ ] **Firewall**: Ports 80, 443, 2222, 5050 accessible

### DNS Configuration ✅
```bash
# Add these DNS records:
gitlab.vise.local     A    YOUR_SERVER_IP
registry.vise.local   A    YOUR_SERVER_IP
monitoring.vise.local A    YOUR_SERVER_IP
```

### SSL Certificates (Optional but Recommended) ✅
```bash
# For production, use Let's Encrypt or internal CA
# Update docker-compose.gitlab.yml with SSL configuration
```

## 🚀 Step-by-Step Deployment

### Step 1: System Preparation

#### 1.1 Update System
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git htop jq

# CentOS/RHEL
sudo yum update -y
sudo yum install -y curl wget git htop jq
```

#### 1.2 Install Docker
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### 1.3 System Optimization
```bash
# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize kernel parameters
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=2097152" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Create swap if needed (for containers)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Step 2: Project Setup

#### 2.1 Clone VISE Project
```bash
# Navigate to deployment directory
cd /opt
sudo mkdir -p vise-cicd
sudo chown $USER:$USER vise-cicd
cd vise-cicd

# Copy CI/CD configuration files
# (Assuming files are already in your vise project)
cp -r /path/to/vise/ci-cd/* .
```

#### 2.2 Directory Structure Verification
```bash
# Verify directory structure
tree -L 3
# Should show:
# .
# ├── docker-compose.gitlab.yml
# ├── monitoring/
# ├── nginx/
# ├── pipelines/
# ├── runner-configs/
# ├── scripts/
# └── security/
```

#### 2.3 Create Data Directories
```bash
# Create persistent data directories
mkdir -p {gitlab/{config,logs,data,backups},postgresql-data,redis-data,runner-config-{1,2,3}}
mkdir -p monitoring/{prometheus-data,grafana-data,alertmanager-data,loki-data}
mkdir -p cache/runner-{1,2,3}

# Set proper permissions
sudo chown -R 998:998 gitlab/
sudo chown -R 472:472 monitoring/grafana-data/
```

### Step 3: Configuration

#### 3.1 Environment Configuration
```bash
# Create environment file
cat > .env << 'EOF'
# GitLab Configuration
GITLAB_EXTERNAL_URL=http://gitlab.vise.local
GITLAB_REGISTRY_EXTERNAL_URL=http://gitlab.vise.local:5050
GITLAB_SSH_PORT=2222

# Database Configuration
POSTGRES_DB=gitlabhq_production
POSTGRES_USER=gitlab
POSTGRES_PASSWORD=SecurePassword123!

# Redis Configuration
REDIS_PASSWORD=

# Monitoring Configuration
GRAFANA_ADMIN_PASSWORD=ViseAdmin2025!
PROMETHEUS_RETENTION=30d

# Security Configuration
MAX_CRITICAL_VULNERABILITIES=0
MAX_HIGH_VULNERABILITIES=5

# Performance Configuration
GITLAB_MEMORY_LIMIT=8g
RUNNER_MEMORY_LIMIT=4g
EOF
```

#### 3.2 Update Docker Compose Configuration
```bash
# Update docker-compose.gitlab.yml with production settings
sed -i 's/gitlab.vise.local/your-actual-domain.com/g' docker-compose.gitlab.yml
sed -i 's/gitlab_db_password/SecurePassword123!/g' docker-compose.gitlab.yml
```

### Step 4: Initial Deployment

#### 4.1 Start Core Services
```bash
# Start GitLab infrastructure
docker-compose -f docker-compose.gitlab.yml up -d

# Monitor startup (this takes 5-10 minutes)
echo "Starting GitLab services..."
docker-compose -f docker-compose.gitlab.yml logs -f gitlab
```

#### 4.2 Wait for GitLab Initialization
```bash
# Wait for GitLab to be ready
echo "Waiting for GitLab to initialize..."
timeout=600  # 10 minutes timeout
counter=0

while ! curl -f http://gitlab.vise.local/health >/dev/null 2>&1; do
    if [ $counter -gt $timeout ]; then
        echo "GitLab failed to start within timeout"
        exit 1
    fi
    echo "Waiting... ($counter seconds)"
    sleep 10
    counter=$((counter + 10))
done

echo "GitLab is ready!"
```

#### 4.3 Get Initial Root Password
```bash
# Get the initial root password
GITLAB_ROOT_PASSWORD=$(docker exec gitlab-ce cat /etc/gitlab/initial_root_password 2>/dev/null | grep Password: | awk '{print $2}')
echo "GitLab Root Password: $GITLAB_ROOT_PASSWORD"

# Save to secure location
echo "GitLab Root Password: $GITLAB_ROOT_PASSWORD" > gitlab_credentials.txt
chmod 600 gitlab_credentials.txt
```

### Step 5: GitLab Configuration

#### 5.1 Initial Login and Setup
```bash
echo "Please complete GitLab setup:"
echo "1. Open: http://gitlab.vise.local"
echo "2. Username: root"
echo "3. Password: $GITLAB_ROOT_PASSWORD"
echo "4. Change password and configure admin settings"
```

#### 5.2 Configure GitLab Settings via UI
1. **Admin Area → Settings → General**
   - Set sign-up restrictions
   - Configure account limits
   - Set default project features

2. **Admin Area → Settings → CI/CD**
   - Maximum artifacts size: 1000 MB
   - Default artifacts expiration: 1 week
   - Maximum timeout: 3 hours
   - Shared runners: Enable

3. **Admin Area → Settings → Repository**
   - Default branch: main
   - Repository size limit: 5000 MB

#### 5.3 Get Runner Registration Token
```bash
# In GitLab UI:
# Admin Area → Runners → Register an instance runner
# Copy the registration token
```

### Step 6: Runner Configuration

#### 6.1 Configure and Start Runners
```bash
# Set registration token (replace with actual token)
export GITLAB_REGISTRATION_TOKEN="glrt-your-actual-token-here"

# Run the setup script
chmod +x scripts/setup-runners.sh
./scripts/setup-runners.sh

# Verify runners are registered
docker exec gitlab-runner-1 gitlab-runner list
docker exec gitlab-runner-2 gitlab-runner list
docker exec gitlab-runner-3 gitlab-runner list
```

#### 6.2 Test Runner Connectivity
```bash
# Test runner functionality
docker exec gitlab-runner-1 gitlab-runner verify --url http://gitlab.vise.local
docker exec gitlab-runner-2 gitlab-runner verify --url http://gitlab.vise.local
docker exec gitlab-runner-3 gitlab-runner verify --url http://gitlab.vise.local
```

### Step 7: Monitoring Setup

#### 7.1 Start Monitoring Stack
```bash
# Start monitoring services
docker-compose -f monitoring/docker-compose.monitoring.yml up -d

# Wait for services to initialize
sleep 60

# Verify monitoring services
curl -f http://localhost:9090/targets    # Prometheus
curl -f http://localhost:3000           # Grafana
curl -f http://localhost:9093           # AlertManager
```

#### 7.2 Configure Grafana Dashboards
```bash
# Access Grafana
echo "Grafana URL: http://monitoring.vise.local:3000"
echo "Username: admin"
echo "Password: ViseAdmin2025!"

# Import pre-configured dashboards
# 1. GitLab CI/CD Performance Dashboard
# 2. System Metrics Dashboard
# 3. Security Scanning Dashboard
# 4. Application Performance Dashboard
```

### Step 8: Security Configuration

#### 8.1 Enable Security Scanning
```bash
# Copy security pipeline configuration
cp security/security-pipeline.yml .gitlab-ci-security.yml

# Configure security thresholds in GitLab variables:
# CI/CD Settings → Variables:
# - MAX_CRITICAL_VULNERABILITIES: 0
# - MAX_HIGH_VULNERABILITIES: 5
# - SECURITY_SCAN_ENABLED: true
```

#### 8.2 SSL Configuration (Production)
```bash
# If using Let's Encrypt:
sudo apt install certbot

# Generate certificates
sudo certbot certonly --standalone -d gitlab.vise.local -d registry.vise.local

# Update GitLab configuration
cat >> gitlab/config/gitlab.rb << 'EOF'
external_url 'https://gitlab.vise.local'
registry_external_url 'https://registry.vise.local'

nginx['ssl_certificate'] = "/etc/letsencrypt/live/gitlab.vise.local/fullchain.pem"
nginx['ssl_certificate_key'] = "/etc/letsencrypt/live/gitlab.vise.local/privkey.pem"
EOF

# Restart GitLab
docker exec gitlab-ce gitlab-ctl reconfigure
```

### Step 9: Project Integration

#### 9.1 Create VISE Project in GitLab
```bash
# In GitLab UI:
# 1. Create new project: "VISE"
# 2. Initialize with README
# 3. Set visibility to Internal
# 4. Enable CI/CD features
```

#### 9.2 Push VISE Code to GitLab
```bash
# From your VISE project directory
cd /path/to/vise

# Add GitLab remote
git remote add gitlab http://gitlab.vise.local/root/vise.git

# Push code
git push gitlab main

# Copy CI/CD configurations
cp ci-cd/.gitlab-ci.yml .
cp ci-cd/vise-backend/.gitlab-ci.yml vise-backend/
cp ci-cd/vise-frontend/.gitlab-ci.yml vise-frontend/

# Commit and push
git add .
git commit -m "Add CI/CD pipeline configuration"
git push gitlab main
```

### Step 10: Testing and Validation

#### 10.1 Test Pipeline Execution
```bash
# Trigger a pipeline by making a small change
echo "# CI/CD Pipeline Active" >> README.md
git add README.md
git commit -m "Test CI/CD pipeline"
git push gitlab main

# Monitor pipeline in GitLab UI
echo "Check pipeline at: http://gitlab.vise.local/root/vise/-/pipelines"
```

#### 10.2 Performance Testing
```bash
# Run metrics collection
./monitoring/scripts/collect-metrics.sh

# Check system resources
htop
docker stats

# Monitor Grafana dashboards
echo "Monitor performance at: http://monitoring.vise.local:3000"
```

#### 10.3 Load Testing (Optional)
```bash
# Create multiple test commits to simulate load
for i in {1..10}; do
  echo "Test commit $i" >> test-load.txt
  git add test-load.txt
  git commit -m "Load test commit $i"
  git push gitlab main
  sleep 30
done
```

## 🔒 Production Hardening

### Security Checklist
```bash
# 1. Change default passwords
# 2. Enable 2FA for admin accounts
# 3. Configure firewall rules
# 4. Set up SSL certificates
# 5. Enable audit logging
# 6. Configure backup strategy
# 7. Implement monitoring alerts
```

### Backup Configuration
```bash
# Create backup script
cat > scripts/backup-production.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/backups/gitlab"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup GitLab data
docker exec gitlab-ce gitlab-backup create BACKUP=$DATE

# Backup configuration
docker exec gitlab-ce tar -czf /var/opt/gitlab/backups/gitlab-config-$DATE.tar.gz /etc/gitlab/

# Copy to backup location
docker cp gitlab-ce:/var/opt/gitlab/backups/ $BACKUP_DIR/

echo "Backup completed: $BACKUP_DIR/$DATE"
EOF

chmod +x scripts/backup-production.sh

# Schedule daily backups
echo "0 2 * * * /opt/vise-cicd/scripts/backup-production.sh" | crontab -
```

### Monitoring Alerts
```bash
# Configure AlertManager notifications
cat > monitoring/alertmanager/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@vise.local'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  email_configs:
  - to: 'admin@vise.local'
    subject: 'GitLab CI/CD Alert: {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      {{ end }}
EOF
```

## 📊 Performance Optimization

### For 500 Developers
```bash
# 1. Database tuning
docker exec gitlab-postgresql psql -U gitlab -d gitlabhq_production -c "
ALTER SYSTEM SET max_connections = 500;
ALTER SYSTEM SET shared_buffers = '4GB';
ALTER SYSTEM SET effective_cache_size = '8GB';
SELECT pg_reload_conf();
"

# 2. GitLab configuration optimization
cat >> gitlab/config/gitlab.rb << 'EOF'
# Performance tuning for 500 developers
sidekiq['max_concurrency'] = 50
unicorn['worker_processes'] = 16
unicorn['worker_timeout'] = 60

# CI/CD optimizations
gitlab_ci['max_artifacts_size'] = 2000
gitlab_rails['artifacts_enabled'] = true
gitlab_rails['artifacts_path'] = "/var/opt/gitlab/gitlab-rails/shared/artifacts"

# Cache configuration
gitlab_rails['redis_cache_instance'] = 'redis://redis:6379/0'
gitlab_rails['redis_queues_instance'] = 'redis://redis:6379/1'
EOF

# 3. Add more runners for scaling
for i in {4..8}; do
  docker run -d --name gitlab-runner-$i \
    --restart always \
    -v ./runner-config-$i:/etc/gitlab-runner \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --network gitlab-network \
    gitlab/gitlab-runner:v16.8.1
done

# Register additional runners
export GITLAB_REGISTRATION_TOKEN="your-token"
for i in {4..8}; do
  docker exec gitlab-runner-$i gitlab-runner register \
    --non-interactive \
    --url="http://gitlab.vise.local" \
    --registration-token="$GITLAB_REGISTRATION_TOKEN" \
    --executor="docker" \
    --docker-image="alpine:3.19" \
    --description="docker-runner-$i" \
    --tag-list="docker,runner-$i" \
    --run-untagged="true" \
    --locked="false"
done
```

## 🎯 Success Validation

### Deployment Success Criteria
- [ ] GitLab accessible at configured URL
- [ ] All runners registered and active
- [ ] Test pipeline executes successfully
- [ ] Monitoring dashboards showing data
- [ ] Security scans executing
- [ ] Backup strategy implemented

### Performance Validation
```bash
# Check key metrics
curl -s http://localhost:9090/api/v1/query?query=up | jq .
curl -s http://localhost:9090/api/v1/query?query=gitlab_runner_jobs | jq .

# Expected results for 500 developers:
# - Pipeline success rate: > 95%
# - Average build time: < 15 minutes
# - Concurrent jobs: 50+
# - System availability: > 99%
```

## 🚨 Troubleshooting

### Common Deployment Issues

#### GitLab Won't Start
```bash
# Check logs
docker logs gitlab-ce

# Check disk space
df -h

# Increase shared memory if needed
docker update --shm-size=1g gitlab-ce
```

#### Runners Not Connecting
```bash
# Verify network connectivity
docker exec gitlab-runner-1 ping gitlab

# Check registration
docker exec gitlab-runner-1 gitlab-runner list

# Re-register if needed
docker exec gitlab-runner-1 gitlab-runner unregister --all-runners
# Then re-run setup script
```

#### Performance Issues
```bash
# Check resource usage
htop
docker stats

# Monitor GitLab performance
docker exec gitlab-ce gitlab-ctl status

# Check database performance
docker exec gitlab-postgresql psql -U gitlab -d gitlabhq_production -c "SELECT * FROM pg_stat_activity;"
```

## 📞 Support and Maintenance

### Regular Maintenance Tasks
```bash
# Weekly tasks
./scripts/backup-production.sh
docker system prune -f
docker volume prune -f

# Monthly tasks
docker exec gitlab-ce gitlab-ctl upgrade
docker pull gitlab/gitlab-ce:latest
docker pull gitlab/gitlab-runner:latest

# Monitor and update
./monitoring/scripts/collect-metrics.sh
```

### Contact Information
- **Documentation**: See README.md for detailed configuration
- **Monitoring**: http://monitoring.vise.local:3000
- **GitLab**: http://gitlab.vise.local
- **Support**: Check GitLab Community Forum for issues

---

**Deployment Complete!** 🎉

Your GitLab CE CI/CD pipeline is now ready to support 500 developers with high-performance, secure, and scalable development workflows.