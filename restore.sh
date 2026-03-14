#!/bin/bash
# Restore Home Assistant configuration from backup
# Usage: ./restore.sh <backup-file>

set -e

SERVER="aziz@10.0.0.51"
REMOTE_HA_PATH="/home/aziz/home-assistant-config"

if [ -z "$1" ]; then
  echo "Usage: ./restore.sh <backup-file>"
  echo ""
  echo "Available backups:"
  ls -lh ~/ha-backups/ha-backup-* 2>/dev/null || echo "  No backups found in ~/ha-backups/"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file not found: $BACKUP_FILE"
  exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Home Assistant Restore ===${NC}"
echo -e "Backup: ${BACKUP_FILE}"
echo ""
echo -e "${RED}WARNING: This will overwrite the current HA configuration!${NC}"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Restore cancelled."
  exit 0
fi

# Handle encrypted backups
TEMP_FILE=""
if [[ "$BACKUP_FILE" == *.gpg ]]; then
  echo -e "${YELLOW}Decrypting backup...${NC}"
  TEMP_FILE="/tmp/ha-restore-$$.tar.gz"
  gpg -d "$BACKUP_FILE" > "$TEMP_FILE"
  BACKUP_FILE="$TEMP_FILE"
fi

# Stop HA
echo -e "${YELLOW}Stopping Home Assistant...${NC}"
ssh "${SERVER}" "cd ${REMOTE_HA_PATH} && docker compose stop homeassistant"

# Upload and extract
echo -e "${YELLOW}Uploading backup to server...${NC}"
scp "$BACKUP_FILE" "${SERVER}:/tmp/ha-restore.tar.gz"

echo -e "${YELLOW}Extracting backup...${NC}"
ssh "${SERVER}" "cd ${REMOTE_HA_PATH} && rm -rf config.bak && mv config config.bak && mkdir config && tar -xzf /tmp/ha-restore.tar.gz -C . && rm /tmp/ha-restore.tar.gz"

# Fix permissions
echo -e "${YELLOW}Fixing permissions...${NC}"
ssh "${SERVER}" "sudo chown -R aziz:aziz ${REMOTE_HA_PATH}/config/" 2>/dev/null || \
  echo -e "${YELLOW}Could not fix permissions - you may need to run: sudo chown -R aziz:aziz ${REMOTE_HA_PATH}/config/${NC}"

# Start HA
echo -e "${YELLOW}Starting Home Assistant...${NC}"
ssh "${SERVER}" "cd ${REMOTE_HA_PATH} && docker compose start homeassistant"

# Cleanup
if [ -n "$TEMP_FILE" ]; then
  rm -f "$TEMP_FILE"
fi

echo ""
echo -e "${GREEN}=== Restore Complete ===${NC}"
echo -e "Previous config backed up to: ${REMOTE_HA_PATH}/config.bak"
echo -e "Home Assistant is starting up..."
