#!/bin/bash

################################################################################
# Backup Keycloak PostgreSQL Database
#
# This script creates a compressed SQL backup of the keycloak_db database
#
# Usage: ./backup-keycloak-database.sh
################################################################################

set -e

BACKUP_DIR="../backups/database"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "================================================"
echo "  Keycloak Database Backup"
echo "================================================"
echo ""

# Create backup directory
mkdir -p $BACKUP_DIR

# Check if PostgreSQL is running
if ! podman exec nexus-postgres-dev pg_isready -U admin > /dev/null 2>&1; then
    echo -e "${RED}❌ PostgreSQL is not running!${NC}"
    echo "   Start with: podman start nexus-postgres-dev"
    exit 1
fi

echo -e "${GREEN}✓ PostgreSQL is ready${NC}"

# Backup keycloak_db
echo "📦 Creating database backup..."
podman exec nexus-postgres-dev pg_dump -U admin keycloak_db \
  > "$BACKUP_DIR/keycloak_db_${DATE}.sql"

echo -e "${GREEN}✓ SQL dump created${NC}"

# Compress backup
echo "🗜️  Compressing backup..."
gzip "$BACKUP_DIR/keycloak_db_${DATE}.sql"

echo -e "${GREEN}✓ Backup compressed${NC}"

# Create latest symlink
cd $BACKUP_DIR
ln -sf "keycloak_db_${DATE}.sql.gz" "keycloak_db_latest.sql.gz"
cd - > /dev/null

# Cleanup old backups
echo "🧹 Cleaning up old backups (older than $RETENTION_DAYS days)..."
OLD_BACKUPS=$(find $BACKUP_DIR -name "keycloak_db_*.sql.gz" -mtime +$RETENTION_DAYS | wc -l)
find $BACKUP_DIR -name "keycloak_db_*.sql.gz" -mtime +$RETENTION_DAYS -delete

if [ $OLD_BACKUPS -gt 0 ]; then
    echo -e "${YELLOW}  Deleted $OLD_BACKUPS old backup(s)${NC}"
else
    echo "  No old backups to delete"
fi

# Summary
BACKUP_SIZE=$(du -h "$BACKUP_DIR/keycloak_db_${DATE}.sql.gz" | cut -f1)
BACKUP_COUNT=$(ls -1 $BACKUP_DIR/keycloak_db_*.sql.gz 2>/dev/null | wc -l)

echo ""
echo "================================================"
echo "  Backup Summary"
echo "================================================"
echo "  Backup File: keycloak_db_${DATE}.sql.gz"
echo "  Size: $BACKUP_SIZE"
echo "  Location: $BACKUP_DIR"
echo "  Total Backups: $BACKUP_COUNT"
echo ""
echo -e "${GREEN}✅ Backup completed successfully!${NC}"
echo ""
echo "To restore this backup:"
echo "  gunzip -c $BACKUP_DIR/keycloak_db_${DATE}.sql.gz | \\"
echo "    podman exec -i nexus-postgres-dev psql -U admin -d keycloak_db"
echo ""
