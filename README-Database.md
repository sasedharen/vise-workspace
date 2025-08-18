# VISE Database Management Guide

## Quick Start

### 1. Start Database with Persistent Storage
```bash
# Start all services (PostgreSQL + Redis + Backup)
docker compose up -d

# Check service status
docker compose ps

# View logs
docker compose logs postgres
docker compose logs db-backup
```

### 2. Stop Database (Data Preserved)
```bash
# Stop services but keep data
docker compose down

# Stop and remove everything including volumes (⚠️ DATA LOSS)
docker compose down -v
```

## Database Persistence Strategy

### Named Volumes (Persistent)
- **PostgreSQL Data**: `vise_postgres_data` volume
- **Redis Data**: `vise_redis_data` volume
- **Backups**: `./backups/` directory (host mounted)

### Volume Management
```bash
# List volumes
docker volume ls | grep vise

# Inspect volume
docker volume inspect vise_postgres_data

# Backup volume
docker run --rm -v vise_postgres_data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/postgres_volume_backup.tar.gz -C /data .

# Restore volume
docker run --rm -v vise_postgres_data:/data -v $(pwd)/backups:/backup alpine tar xzf /backup/postgres_volume_backup.tar.gz -C /data
```

## Automated Backup System

### Backup Schedule
- **Hourly**: Every hour, keeps last 24 backups
- **Daily**: At 2 AM, keeps last 7 days  
- **Weekly**: Sunday 3 AM, keeps last 4 weeks

### Backup Locations
```
backups/
├── hourly/          # Last 24 hours
├── daily/           # Last 7 days
├── weekly/          # Last 4 weeks
└── last_backup_info.json
```

### Manual Backup
```bash
# Create immediate backup
docker exec vise-postgres pg_dump -U postgres vise > backups/manual_backup_$(date +%Y%m%d_%H%M%S).sql

# Create compressed backup
docker exec vise-postgres pg_dump -U postgres vise | gzip > backups/manual_backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Restore from Backup
```bash
# Restore from specific backup
./scripts/restore-backup.sh backups/hourly/vise_backup_20250814_120000.sql.gz

# Restore latest backup
./scripts/restore-backup.sh $(ls -t backups/hourly/*.sql.gz | head -1)

# List available backups
find backups/ -name "*.sql.gz" -o -name "*.dump" | sort -r
```

## Database Migration Management

### Check Migration Status
```bash
# View current migration version
docker exec vise-postgres psql -U postgres -d vise -c "SELECT version FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 1;"

# View all applied migrations
docker exec vise-postgres psql -U postgres -d vise -c "SELECT installed_rank, version, description, success FROM flyway_schema_history ORDER BY installed_rank;"
```

### Run Migrations
```bash
# Run pending migrations
make migrate

# Check migration status
make migrate-info
```

## Troubleshooting

### Data Loss Recovery
If you lose your database:

1. **Check for backups**:
   ```bash
   ls -la backups/hourly/ | head -5
   ```

2. **Restore from latest backup**:
   ```bash
   ./scripts/restore-backup.sh $(ls -t backups/hourly/*.sql.gz | head -1)
   ```

3. **If no backups, rebuild from migrations**:
   ```bash
   make migrate
   ```

### Common Issues

#### Container Won't Start
```bash
# Check logs
docker compose logs postgres

# Remove container and restart
docker compose down
docker compose up -d postgres
```

#### Permission Issues
```bash
# Fix backup directory permissions
chmod -R 755 backups/
chmod +x scripts/*.sh
```

#### Port Conflicts
```bash
# Check what's using port 5432
lsof -i :5432

# Kill conflicting process
sudo kill -9 <PID>
```

### Health Checks
```bash
# Check PostgreSQL health
docker exec vise-postgres pg_isready -U postgres

# Check Redis health  
docker exec vise-redis redis-cli ping

# Check database connectivity
PGPASSWORD=vise psql -h localhost -U postgres -d vise -c "SELECT NOW();"
```

## Backup Verification

### Verify Backup Integrity
```bash
# Test restore in temporary database
docker run --rm postgres:15 pg_restore --list backups/hourly/latest.dump

# Verify backup metadata
cat backups/last_backup_info.json | jq '.'
```

### Monitor Backup Status
```bash
# Check backup service logs
docker compose logs db-backup

# Check backup file sizes
du -sh backups/*

# Count backup files
find backups/ -name "*.sql.gz" | wc -l
```

## Data Protection Best Practices

1. **Multiple Backup Types**: Hourly, daily, and weekly backups
2. **Off-site Storage**: Copy critical backups to external storage
3. **Regular Testing**: Test restore process monthly
4. **Version Control**: Keep migration files in Git
5. **Monitoring**: Set up alerts for backup failures

## Emergency Procedures

### Complete Database Loss
1. Stop application to prevent data corruption
2. Start fresh database: `docker compose up -d postgres`
3. Restore from latest backup: `./scripts/restore-backup.sh`
4. Verify data integrity
5. Resume application

### Backup System Failure
1. Check backup service: `docker compose logs db-backup`
2. Restart backup service: `docker compose restart db-backup`
3. Create manual backup immediately
4. Fix underlying issue before relying on automated backups

This setup ensures your database is protected against accidental loss while maintaining high availability and easy recovery options.