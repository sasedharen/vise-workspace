#!/bin/bash

# Database backup script with hourly execution
# Maintains last 24 hours, daily for 7 days, weekly for 4 weeks

set -e

BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
HOUR=$(date +"%H")
DAY=$(date +"%A")

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h postgres -U postgres; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "PostgreSQL is ready - starting backup process"

# Function to create backup
create_backup() {
    local backup_type=$1
    local backup_file="${BACKUP_DIR}/${backup_type}/vise_backup_${TIMESTAMP}.sql"
    
    mkdir -p "${BACKUP_DIR}/${backup_type}"
    
    echo "Creating ${backup_type} backup: ${backup_file}"
    
    # Create compressed backup with all schemas and data
    pg_dump -h postgres -U postgres -d vise \
        --verbose \
        --format=custom \
        --compress=9 \
        --no-owner \
        --no-privileges \
        --schema=users \
        --schema=codes \
        --schema=public \
        > "${backup_file}.dump"
    
    # Also create SQL backup for easy inspection
    pg_dump -h postgres -U postgres -d vise \
        --verbose \
        --no-owner \
        --no-privileges \
        --schema=users \
        --schema=codes \
        --schema=public \
        > "${backup_file}"
    
    # Compress SQL backup
    gzip "${backup_file}"
    
    echo "✅ ${backup_type} backup completed: ${backup_file}.gz and ${backup_file}.dump"
}

# Function to cleanup old backups
cleanup_old_backups() {
    local backup_type=$1
    local retention_days=$2
    
    echo "Cleaning up ${backup_type} backups older than ${retention_days} days"
    find "${BACKUP_DIR}/${backup_type}" -name "*.sql.gz" -mtime +${retention_days} -delete
    find "${BACKUP_DIR}/${backup_type}" -name "*.dump" -mtime +${retention_days} -delete
}

# Hourly backup (keep last 24 hours)
create_backup "hourly"
cleanup_old_backups "hourly" 1

# Daily backup at 2 AM (keep last 7 days)
if [ "$HOUR" = "02" ]; then
    create_backup "daily"
    cleanup_old_backups "daily" 7
fi

# Weekly backup on Sunday at 3 AM (keep last 4 weeks)
if [ "$DAY" = "Sunday" ] && [ "$HOUR" = "03" ]; then
    create_backup "weekly"
    cleanup_old_backups "weekly" 28
fi

# Create backup metadata
cat > "${BACKUP_DIR}/last_backup_info.json" <<EOF
{
    "timestamp": "${TIMESTAMP}",
    "date": "$(date -Iseconds)",
    "database": "vise",
    "schemas": ["users", "codes", "public"],
    "migration_version": "$(PGPASSWORD=vise psql -h postgres -U postgres -d vise -t -c "SELECT version FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 1;" | xargs)",
    "backup_types": ["hourly"],
    "retention": {
        "hourly": "24 hours",
        "daily": "7 days", 
        "weekly": "4 weeks"
    }
}
EOF

echo "✅ Backup metadata updated"

# Sleep for 1 hour before next backup
sleep 3600