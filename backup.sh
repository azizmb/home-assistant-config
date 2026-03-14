#!/bin/bash
# Backup Home Assistant configuration (including .storage, users, integrations)
# Usage: ./backup.sh [--encrypt] [--remote user@host:/path]

set -e

SERVER="aziz@10.0.0.51"
REMOTE_HA_PATH="/home/aziz/home-assistant-config"
LOCAL_BACKUP_DIR="$HOME/ha-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="ha-backup-${TIMESTAMP}"
ENCRYPT=false
REMOTE_BACKUP=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --encrypt)
      ENCRYPT=true
      shift
      ;;
    --remote)
      REMOTE_BACKUP="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./backup.sh [--encrypt] [--remote user@host:/path]"
      exit 1
      ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "${LOCAL_BACKUP_DIR}"

echo -e "${YELLOW}=== Home Assistant Backup ===${NC}"
echo -e "${YELLOW}Timestamp: ${TIMESTAMP}${NC}"

# Stop HA to ensure consistent backup
echo -e "${YELLOW}Stopping Home Assistant...${NC}"
ssh "${SERVER}" "cd ${REMOTE_HA_PATH} && docker compose stop homeassistant"

# Create backup on server first (faster)
echo -e "${YELLOW}Creating backup archive on server...${NC}"
ssh "${SERVER}" "cd ${REMOTE_HA_PATH} && tar -czf /tmp/${BACKUP_NAME}.tar.gz \
  --exclude='config/home-assistant.log*' \
  --exclude='config/deps' \
  --exclude='config/tts' \
  --exclude='config/__pycache__' \
  config/"

# Restart HA immediately (don't wait for download)
echo -e "${YELLOW}Restarting Home Assistant...${NC}"
ssh "${SERVER}" "cd ${REMOTE_HA_PATH} && docker compose start homeassistant"

# Download backup
echo -e "${YELLOW}Downloading backup...${NC}"
scp "${SERVER}:/tmp/${BACKUP_NAME}.tar.gz" "${LOCAL_BACKUP_DIR}/"

# Clean up server temp file
ssh "${SERVER}" "rm /tmp/${BACKUP_NAME}.tar.gz"

# Encrypt if requested
if [ "$ENCRYPT" = true ]; then
  echo -e "${YELLOW}Encrypting backup...${NC}"
  if ! command -v gpg &> /dev/null; then
    echo -e "${RED}gpg not found. Install it or use --encrypt with gpg available.${NC}"
  else
    gpg --symmetric --cipher-algo AES256 "${LOCAL_BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    rm "${LOCAL_BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    BACKUP_NAME="${BACKUP_NAME}.tar.gz.gpg"
    echo -e "${GREEN}Backup encrypted: ${LOCAL_BACKUP_DIR}/${BACKUP_NAME}${NC}"
  fi
else
  BACKUP_NAME="${BACKUP_NAME}.tar.gz"
fi

# Copy to remote if specified
if [ -n "$REMOTE_BACKUP" ]; then
  echo -e "${YELLOW}Copying to remote: ${REMOTE_BACKUP}${NC}"
  scp "${LOCAL_BACKUP_DIR}/${BACKUP_NAME}" "${REMOTE_BACKUP}/"
  echo -e "${GREEN}Remote backup complete!${NC}"
fi

# Cleanup old backups (keep last 5)
echo -e "${YELLOW}Cleaning up old backups (keeping last 5)...${NC}"
ls -t "${LOCAL_BACKUP_DIR}"/ha-backup-* 2>/dev/null | tail -n +6 | xargs -r rm --

# Summary
BACKUP_SIZE=$(du -h "${LOCAL_BACKUP_DIR}/${BACKUP_NAME}" | cut -f1)
echo ""
echo -e "${GREEN}=== Backup Complete ===${NC}"
echo -e "Location: ${LOCAL_BACKUP_DIR}/${BACKUP_NAME}"
echo -e "Size: ${BACKUP_SIZE}"
echo ""
echo -e "${YELLOW}To restore:${NC}"
if [ "$ENCRYPT" = true ]; then
  echo "  gpg -d ${LOCAL_BACKUP_DIR}/${BACKUP_NAME} | tar -xzf - -C /path/to/restore/"
else
  echo "  tar -xzf ${LOCAL_BACKUP_DIR}/${BACKUP_NAME} -C /path/to/restore/"
fi
