#!/bin/bash

# Database restore script
# Usage: ./restore-backup.sh <backup_file> [backup_type]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_file> [backup_type]"
    echo "Example: $0 /backups/hourly/vise_backup_20250814_120000.sql.gz"
    echo "Example: $0 vise_backup_20250814_120000.sql.gz hourly"
    exit 1
fi

BACKUP_FILE=$1
BACKUP_TYPE=${2:-"hourly"}
BACKUP_DIR="/backups"

# If relative path provided, construct full path
if [[ ! "$BACKUP_FILE" == /* ]]; then
    BACKUP_FILE="${BACKUP_DIR}/${BACKUP_TYPE}/${BACKUP_FILE}"
fi

echo "🔄 Starting database restore from: ${BACKUP_FILE}"

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h postgres -U postgres; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

# Check if backup file exists
if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    echo "Available backups:"
    find "$BACKUP_DIR" -name "*.sql.gz" -o -name "*.dump" | sort -r | head -10
    exit 1
fi

echo "✅ Found backup file: $BACKUP_FILE"

# Determine file type and restore accordingly
if [[ "$BACKUP_FILE" == *.dump ]]; then
    echo "🔄 Restoring from custom format dump..."
    
    # Drop existing database and recreate
    echo "Dropping and recreating database..."
    PGPASSWORD=vise psql -h postgres -U postgres -c "DROP DATABASE IF EXISTS vise;"
    PGPASSWORD=vise psql -h postgres -U postgres -c "CREATE DATABASE vise;"
    
    # Restore from custom dump
    PGPASSWORD=vise pg_restore -h postgres -U postgres -d vise \
        --verbose \
        --clean \
        --no-owner \
        --no-privileges \
        "$BACKUP_FILE"
        
elif [[ "$BACKUP_FILE" == *.gz ]]; then
    echo "🔄 Restoring from compressed SQL dump..."
    
    # Drop existing schemas and recreate
    echo "Cleaning existing schemas..."
    PGPASSWORD=vise psql -h postgres -U postgres -d vise -c "
        DROP SCHEMA IF EXISTS users CASCADE;
        DROP SCHEMA IF EXISTS codes CASCADE;
        DELETE FROM flyway_schema_history WHERE version > '35';
    "
    
    # Restore from compressed SQL
    gunzip -c "$BACKUP_FILE" | PGPASSWORD=vise psql -h postgres -U postgres -d vise
    
else
    echo "🔄 Restoring from SQL dump..."
    
    # Drop existing schemas and recreate
    echo "Cleaning existing schemas..."
    PGPASSWORD=vise psql -h postgres -U postgres -d vise -c "
        DROP SCHEMA IF EXISTS users CASCADE;
        DROP SCHEMA IF EXISTS codes CASCADE;
        DELETE FROM flyway_schema_history WHERE version > '35';
    "
    
    # Restore from SQL
    PGPASSWORD=vise psql -h postgres -U postgres -d vise < "$BACKUP_FILE"
fi

echo "✅ Database restore completed successfully!"

# Verify restore
echo "🔍 Verifying restore..."
SCHEMA_COUNT=$(PGPASSWORD=vise psql -h postgres -U postgres -d vise -t -c "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name IN ('users', 'codes');")
TABLE_COUNT=$(PGPASSWORD=vise psql -h postgres -U postgres -d vise -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('users', 'codes');")
MIGRATION_VERSION=$(PGPASSWORD=vise psql -h postgres -U postgres -d vise -t -c "SELECT version FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 1;" | xargs)

echo "📊 Restore verification:"
echo "  - Schemas restored: $SCHEMA_COUNT"
echo "  - Tables restored: $TABLE_COUNT"
echo "  - Migration version: v$MIGRATION_VERSION"

if [ "$SCHEMA_COUNT" -eq 2 ] && [ "$TABLE_COUNT" -gt 10 ]; then
    echo "✅ Restore verification successful!"
else
    echo "⚠️  Restore verification failed - manual inspection recommended"
    exit 1
fi