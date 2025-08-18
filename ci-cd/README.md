# VISE CI/CD Pipeline Setup Guide

## Docker-Based GitLab CE CI/CD for 500 Developers

This guide provides a complete setup for a scalable, production-ready CI/CD pipeline using GitLab Community Edition, designed to support 500+ developers with high-performance Docker-based workflows.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Installation Steps](#installation-steps)
- [Configuration](#configuration)
- [Monitoring & Scaling](#monitoring--scaling)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)

## 🎯 Overview

### Features
- ✅ **GitLab CE**: Free, unlimited developers
- ✅ **Auto-scaling Runners**: Docker-based with intelligent scaling
- ✅ **Multi-pipeline Support**: Backend (Go), Frontend (React), Database
- ✅ **Comprehensive Security**: SAST, DAST, Container scanning
- ✅ **Full Monitoring**: Prometheus, Grafana, AlertManager
- ✅ **Production Ready**: Designed for 500+ developers

### Performance Targets
- **Concurrent Builds**: 50+ simultaneous pipelines
- **Build Time**: < 10 minutes for full VISE stack
- **Queue Time**: < 30 seconds during peak hours
- **Success Rate**: > 95% pipeline success rate
- **Uptime**: 99.9% CI/CD availability

## 🔧 Prerequisites

### System Requirements
```bash
# Minimum Hardware (Development)
- CPU: 8 cores
- RAM: 16GB
- Storage: 500GB SSD
- Network: 100Mbps

# Recommended Hardware (500 Developers)
- CPU: 16+ cores
- RAM: 32GB+
- Storage: 1TB+ NVMe SSD
- Network: 1Gbps+
```

### Software Requirements
```bash
# Required
- Docker 24.0+
- Docker Compose v2.0+
- Git 2.30+

# Optional but Recommended
- jq (JSON processing)
- curl (API testing)
- htop (system monitoring)
```

### Network Requirements
```bash
# Ports to Open
- 80/tcp    (GitLab HTTP)
- 443/tcp   (GitLab HTTPS)
- 2222/tcp  (GitLab SSH)
- 5050/tcp  (Container Registry)
- 3000/tcp  (Grafana)
- 9090/tcp  (Prometheus)
```

## 🚀 Quick Start

### 1. Clone and Setup
```bash
# Navigate to VISE project
cd /path/to/vise

# Create CI/CD directory structure
mkdir -p ci-cd/{configs,logs,backups}
cd ci-cd

# Copy configuration files (already created above)
# Files are in the ci-cd directory structure
```

### 2. Start GitLab Infrastructure
```bash
# Start GitLab CE and supporting services
docker-compose -f docker-compose.gitlab.yml up -d

# Wait for GitLab to initialize (5-10 minutes)
echo "Waiting for GitLab to start..."
sleep 300

# Check GitLab health
curl -f http://gitlab.vise.local/health
```

### 3. Configure GitLab Runners
```bash
# Set your GitLab registration token
export GITLAB_REGISTRATION_TOKEN="your-token-from-gitlab-admin"

# Run the setup script
./scripts/setup-runners.sh

# Verify runners are registered
docker exec gitlab-runner-1 gitlab-runner list
```

### 4. Start Monitoring
```bash
# Start monitoring stack
docker-compose -f monitoring/docker-compose.monitoring.yml up -d

# Access dashboards
echo "Grafana: http://localhost:3000 (admin/ViseAdmin2025!)"
echo "Prometheus: http://localhost:9090"
```

## 🏗️ Architecture

### Component Overview
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitLab CE     │    │  GitLab Runners │    │   Monitoring    │
│                 │    │                 │    │                 │
│ • Web Interface │    │ • 3x Runners    │    │ • Prometheus    │
│ • Git Repos     │────│ • Auto-scaling  │    │ • Grafana       │
│ • CI/CD Engine  │    │ • Docker Exec   │    │ • AlertManager  │
│ • Registry      │    │ • Specialized   │    │ • Loki          │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
    ┌─────────────────────────────┼─────────────────────────────┐
    │                             │                             │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │     Redis       │    │     Nginx       │
│                 │    │                 │    │                 │
│ • GitLab DB     │    │ • Cache/Queue   │    │ • Load Balancer │
│ • Metadata      │    │ • Sessions      │    │ • SSL Term      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Pipeline Flow
```
Developer Push → GitLab → Trigger Pipeline → Runner Selection → Execute Stages
     │              │           │                    │              │
     └──────────────┼───────────┼────────────────────┼──────────────┘
                    │           │                    │
                Webhook    Queue Job            Specialized
                           Management           Runner Pool
```

## 🔧 Installation Steps

### Step 1: GitLab CE Setup

#### 1.1 Start GitLab
```bash
# Navigate to CI/CD directory
cd ci-cd

# Start GitLab with all dependencies
docker-compose -f docker-compose.gitlab.yml up -d

# Monitor startup logs
docker logs -f gitlab-ce
```

#### 1.2 Initial Configuration
```bash
# Wait for GitLab to be ready
while ! curl -f http://gitlab.vise.local/health; do
  echo "Waiting for GitLab..."
  sleep 30
done

# Get initial root password
docker exec gitlab-ce cat /etc/gitlab/initial_root_password

# Login to GitLab
echo "GitLab URL: http://gitlab.vise.local"
echo "Username: root"
echo "Password: (from command above)"
```

#### 1.3 Configure GitLab Settings
```bash
# Access Admin Area → Settings → CI/CD
# Configure the following:
# - Maximum artifacts size: 1GB
# - Default artifacts expiration: 1 week
# - Maximum timeout: 3 hours
# - Auto DevOps: Disabled (we use custom pipelines)
```

### Step 2: Runner Configuration

#### 2.1 Get Registration Token
```bash
# In GitLab Admin Area → Runners
# Copy the registration token for shared runners
```

#### 2.2 Setup Runners
```bash
# Set environment variable
export GITLAB_REGISTRATION_TOKEN="glrt-your-token-here"

# Run setup script
./scripts/setup-runners.sh

# Verify registration
docker exec gitlab-runner-1 gitlab-runner verify
docker exec gitlab-runner-2 gitlab-runner verify
docker exec gitlab-runner-3 gitlab-runner verify
```

#### 2.3 Configure Runner Specialization
```bash
# Edit runner configurations for optimization
# This is done automatically by the setup script

# Backend runner (runner-2): golang:1.23-alpine base
# Frontend runner (runner-3): node:18-alpine base
# General runner (runner-1): alpine:3.19 base
```

### Step 3: Pipeline Configuration

#### 3.1 Main Pipeline Setup
```bash
# Copy .gitlab-ci.yml to project root
cp .gitlab-ci.yml /path/to/vise/.gitlab-ci.yml

# Copy backend-specific pipeline
cp vise-backend/.gitlab-ci.yml /path/to/vise/vise-backend/

# Copy frontend-specific pipeline
cp vise-frontend/.gitlab-ci.yml /path/to/vise/vise-frontend/
```

#### 3.2 Database Pipeline Setup
```bash
# Copy database pipeline
cp pipelines/database-pipeline.yml /path/to/vise/.gitlab-ci-database.yml

# Copy security pipeline
cp security/security-pipeline.yml /path/to/vise/.gitlab-ci-security.yml
```

### Step 4: Monitoring Setup

#### 4.1 Start Monitoring Stack
```bash
# Start all monitoring services
docker-compose -f monitoring/docker-compose.monitoring.yml up -d

# Wait for services to be ready
sleep 60

# Verify services
curl -f http://localhost:9090/targets    # Prometheus
curl -f http://localhost:3000           # Grafana
```

#### 4.2 Configure Grafana
```bash
# Access Grafana
# URL: http://localhost:3000
# Username: admin
# Password: ViseAdmin2025!

# Import dashboards (JSON files in monitoring/grafana/dashboards/)
# - GitLab CI/CD Dashboard
# - System Metrics Dashboard
# - Security Dashboard
```

## ⚙️ Configuration

### Environment Variables
```bash
# GitLab Configuration
GITLAB_EXTERNAL_URL="http://gitlab.vise.local"
GITLAB_REGISTRY_EXTERNAL_URL="http://gitlab.vise.local:5050"

# Database Configuration
DB_NAME="gitlabhq_production"
DB_USER="gitlab"
DB_PASSWORD="gitlab_db_password"

# Redis Configuration
REDIS_PASSWORD="" # Leave empty for development

# Monitoring Configuration
PROMETHEUS_RETENTION="30d"
GRAFANA_ADMIN_PASSWORD="ViseAdmin2025!"

# Security Configuration
SECURITY_SCAN_ENABLED="true"
MAX_CRITICAL_VULNERABILITIES="0"
MAX_HIGH_VULNERABILITIES="5"
```

### GitLab Configuration
```ruby
# /etc/gitlab/gitlab.rb modifications for 500 developers

# Performance tuning
sidekiq['max_concurrency'] = 50
unicorn['worker_processes'] = 8
unicorn['worker_timeout'] = 60

# CI/CD optimizations
gitlab_ci['builds_directory'] = '/builds'
gitlab_ci['max_artifacts_size'] = 1000

# Database settings
postgresql['max_connections'] = 300
postgresql['shared_buffers'] = "2GB"
postgresql['effective_cache_size'] = "4GB"

# Monitoring
prometheus_monitoring['enable'] = true
grafana['enable'] = true
```

### Runner Configuration Template
```toml
# Example optimized runner config
concurrent = 10
check_interval = 5

[[runners]]
  name = "docker-optimized"
  url = "http://gitlab.vise.local"
  token = "your-token"
  executor = "docker"
  limit = 5
  
  [runners.docker]
    image = "alpine:3.19"
    privileged = true
    memory = "4g"
    cpus = "2.0"
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock",
      "/cache",
      "/builds:/builds:rw"
    ]
    
  [runners.cache]
    Type = "local"
    Path = "/cache"
    Shared = true
```

## 📊 Monitoring & Scaling

### Performance Metrics
```bash
# Key metrics to monitor for 500 developers:

# System Metrics
- CPU Usage: < 80%
- Memory Usage: < 85%
- Disk Usage: < 80%
- Network I/O: Monitor saturation

# GitLab Metrics
- Pipeline success rate: > 95%
- Average build time: < 10 minutes
- Queue time: < 30 seconds
- Concurrent jobs: Target 50+

# Runner Metrics
- Runner availability: > 99%
- Job failure rate: < 5%
- Concurrent utilization: 70-90%
```

### Auto-scaling Configuration
```bash
# Configure runner auto-scaling
# Add to runner config:
[runners.machine]
  MaxBuilds = 20
  IdleCount = 5
  IdleTime = 1800

# Monitor scaling needs
./monitoring/scripts/collect-metrics.sh

# Check recommended scaling
grep "recommended_runners" /tmp/gitlab_custom_metrics.prom
```

### Capacity Planning
```bash
# For 500 developers, plan for:

# Peak Load (9 AM - 6 PM)
- 100+ concurrent jobs
- 200+ pipelines per hour
- 50+ merge requests per hour

# Infrastructure Scaling
- Add runner every 50 active developers
- Scale PostgreSQL at 80% connection utilization
- Add storage every 100GB artifact growth

# Network Planning
- 10Mbps per 50 developers
- 1Gbps recommended for 500 developers
```

## 🔒 Security

### Security Pipeline Features
```bash
# Automated Security Scanning
✅ Secret Detection (TruffleHog)
✅ SAST (GoSec, Semgrep)
✅ Dependency Scanning (Go modules, npm audit)
✅ Container Scanning (Trivy)
✅ DAST (OWASP ZAP)
✅ License Compliance

# Security Gates
- Block deployment on critical vulnerabilities
- Require security approval for production
- Automated security reporting
```

### Security Configuration
```yaml
# Security thresholds in security-pipeline.yml
variables:
  MAX_CRITICAL_VULNERABILITIES: "0"
  MAX_HIGH_VULNERABILITIES: "5"
  MAX_MEDIUM_VULNERABILITIES: "20"

# Security tools versions
  TRIVY_VERSION: "latest"
  GOSEC_VERSION: "latest"
  SEMGREP_VERSION: "latest"
```

### Best Practices
```bash
# Security Best Practices for 500 Developers

1. Access Control
   - Use RBAC (Role-Based Access Control)
   - Limit admin access
   - Regular access reviews

2. Pipeline Security
   - Sign all commits
   - Verify container images
   - Use security scanning

3. Infrastructure Security
   - Regular security updates
   - Network segmentation
   - Encrypted communications

4. Monitoring
   - Security event logging
   - Anomaly detection
   - Regular security audits
```

## 🔧 Troubleshooting

### Common Issues

#### GitLab Won't Start
```bash
# Check logs
docker logs gitlab-ce

# Common fixes
docker system prune -f
docker-compose -f docker-compose.gitlab.yml down
docker-compose -f docker-compose.gitlab.yml up -d

# Check disk space
df -h
```

#### Runners Not Connecting
```bash
# Verify runner registration
docker exec gitlab-runner-1 gitlab-runner list

# Re-register runner
docker exec gitlab-runner-1 gitlab-runner register

# Check network connectivity
docker exec gitlab-runner-1 ping gitlab
```

#### Poor Pipeline Performance
```bash
# Check runner utilization
./monitoring/scripts/collect-metrics.sh

# Monitor resource usage
docker stats

# Check build cache
docker system df

# Optimize cache usage
docker builder prune
```

#### Database Issues
```bash
# Check PostgreSQL status
docker exec gitlab-postgresql pg_isready

# Monitor connections
docker exec gitlab-postgresql psql -U gitlab -d gitlabhq_production -c "SELECT count(*) FROM pg_stat_activity;"

# Check disk space
docker exec gitlab-postgresql df -h
```

### Performance Optimization

#### Runner Optimization
```bash
# Optimize runner concurrency
# Edit runner config files:
concurrent = 10  # Per runner
limit = 5        # Per job type

# Use build cache effectively
[runners.cache]
  Type = "local"
  Path = "/cache"
  Shared = true
```

#### GitLab Optimization
```bash
# Increase worker processes
unicorn['worker_processes'] = 8

# Optimize database
postgresql['shared_buffers'] = "2GB"
postgresql['max_connections'] = 300

# Enable caching
redis['enable'] = true
```

#### Docker Optimization
```bash
# Prune regularly
docker system prune -f --volumes

# Optimize images
# Use multi-stage builds
# Use .dockerignore
# Minimize layer count

# Monitor disk usage
docker system df
```

## 📈 Performance Optimization

### For 500 Developers

#### Infrastructure Scaling
```bash
# Recommended scaling pattern:
# 1-50 developers:   3 runners, 8GB RAM, 4 cores
# 51-150 developers: 5 runners, 16GB RAM, 8 cores
# 151-300 developers: 8 runners, 32GB RAM, 16 cores
# 301-500 developers: 12 runners, 64GB RAM, 24 cores

# Add runners dynamically:
for i in {4..12}; do
  docker run -d --name gitlab-runner-$i \
    -v ./runner-config-$i:/etc/gitlab-runner \
    -v /var/run/docker.sock:/var/run/docker.sock \
    gitlab/gitlab-runner:v16.8.1
done
```

#### Database Optimization
```bash
# PostgreSQL tuning for 500 developers
postgresql['max_connections'] = 500
postgresql['shared_buffers'] = "4GB"
postgresql['effective_cache_size'] = "8GB"
postgresql['work_mem'] = "16MB"
postgresql['maintenance_work_mem'] = "512MB"
```

#### Cache Strategy
```bash
# Multi-layer caching
1. GitLab CI Cache (job artifacts)
2. Docker Layer Cache
3. Application Build Cache (Go modules, npm)
4. Database Query Cache

# Cache optimization
gitlab_ci['max_artifacts_size'] = 2000  # 2GB per job
```

## 🎯 Success Metrics

### KPIs for 500 Developers
```bash
# Development Velocity
- Deployments per day: 100+
- Mean time to deployment: < 30 minutes
- Pipeline success rate: > 95%

# System Performance
- Build queue time: < 1 minute
- Average build time: < 15 minutes
- System availability: > 99.9%

# Developer Experience
- Time to first build: < 5 minutes
- Build feedback time: < 10 minutes
- Self-service deployment: 100%

# Resource Efficiency
- Runner utilization: 70-90%
- Cost per developer: < $10/month
- Infrastructure scaling: Automated
```

## 📚 Additional Resources

### Documentation Links
- [GitLab CE Documentation](https://docs.gitlab.com/ce/)
- [GitLab CI/CD Configuration](https://docs.gitlab.com/ee/ci/)
- [Docker Documentation](https://docs.docker.com/)
- [Prometheus Documentation](https://prometheus.io/docs/)

### Useful Commands
```bash
# GitLab Management
gitlab-ctl status
gitlab-ctl reconfigure
gitlab-ctl tail

# Docker Management
docker-compose logs -f
docker system prune
docker stats

# Monitoring
curl http://localhost:9090/api/v1/targets
curl http://localhost:3000/api/health
```

### Community Support
- [GitLab Community Forum](https://forum.gitlab.com/)
- [GitLab CI/CD Examples](https://gitlab.com/gitlab-org/gitlab/-/tree/master/lib/gitlab/ci/templates)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---

## 🏁 Conclusion

This CI/CD setup provides a robust, scalable platform for 500+ developers with:
- **Zero licensing costs** (GitLab CE)
- **High availability** (99.9%+ uptime)
- **Comprehensive security** (automated scanning)
- **Full observability** (metrics and monitoring)
- **Developer productivity** (fast, reliable pipelines)

The configuration is production-ready and can scale with your team's growth while maintaining performance and reliability standards.

For support and questions, refer to the troubleshooting section or community resources above.