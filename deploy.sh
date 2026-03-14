#!/bin/bash
# Deploy Home Assistant configuration to server
# Usage: ./deploy.sh [--restart]

set -e

SERVER="aziz@10.0.0.51"
REMOTE_PATH="/home/aziz/home-assistant-config"
LOCAL_PATH="$(dirname "$(realpath "$0")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Deploying Home Assistant config to ${SERVER}...${NC}"

# Sync config directory (YAML files, automations, blueprints, etc.)
# --no-perms --no-owner --no-group: avoid permission issues with root-owned files
rsync -rltvz --progress --no-perms --no-owner --no-group \
  --exclude '.storage' \
  --exclude '.cloud' \
  --exclude 'home-assistant_v2.db*' \
  --exclude 'home-assistant.log*' \
  --exclude 'deps' \
  --exclude 'tts' \
  --exclude '__pycache__' \
  --exclude '.pytest_cache' \
  --exclude 'custom_components' \
  --exclude 'www/community' \
  --exclude 'image' \
  --exclude '.HA_VERSION' \
  "${LOCAL_PATH}/config/" "${SERVER}:${REMOTE_PATH}/config/"

echo -e "${GREEN}Config synced successfully!${NC}"

# Sync other directories if they exist
if [ -d "${LOCAL_PATH}/zigbee2mqtt-data" ]; then
  echo -e "${YELLOW}Syncing zigbee2mqtt config...${NC}"
  rsync -rltvz --progress --no-perms --no-owner --no-group \
    --exclude 'coordinator_backup.json' \
    --exclude 'state.json' \
    --exclude 'log' \
    --exclude 'database.db' \
    "${LOCAL_PATH}/zigbee2mqtt-data/" "${SERVER}:${REMOTE_PATH}/zigbee2mqtt-data/"
fi

if [ -d "${LOCAL_PATH}/esphome-config" ]; then
  echo -e "${YELLOW}Syncing esphome config...${NC}"
  rsync -rltvz --progress --no-perms --no-owner --no-group \
    --exclude '.esphome' \
    "${LOCAL_PATH}/esphome-config/" "${SERVER}:${REMOTE_PATH}/esphome-config/"
fi

# Restart if requested
if [ "$1" == "--restart" ]; then
  echo -e "${YELLOW}Restarting Home Assistant...${NC}"
  ssh "${SERVER}" "cd ${REMOTE_PATH} && docker compose restart homeassistant"
  echo -e "${GREEN}Home Assistant restarted!${NC}"
else
  echo -e "${YELLOW}Run with --restart to restart Home Assistant${NC}"
  echo -e "${YELLOW}Or reload automations from HA UI: Settings → Automations → ⋮ → Reload${NC}"
fi

echo -e "${GREEN}Done!${NC}"
