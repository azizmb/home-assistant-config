# Home Assistant Configuration

## Project Overview

Home Assistant configuration with Zigbee2MQTT, MQTT, and Tuya integrations. Manages smart home devices across multiple rooms.

- **HA instance**: `http://10.0.0.51:8123` (API token in `.env`)
- **Z2M runs in Docker** on Raspberry Pi `zigbee-gw` / `10.0.0.13` (container: `zigbee2mqtt`, frontend: port 8080)
- **MQTT broker**: `10.0.0.51:1883` (no auth)
- **ESPHome**: `http://10.0.0.51:6052` (container: `esphome`, host networking)
- **SSH access**: `aziz@10.0.0.51` (server), `aziz@10.0.0.13` (Pi)

## Key Directories

- `config/automations/` — HA automations organized by room
- `config/blueprints/` — reusable automation blueprints
- `zigbee2mqtt-data/` — local copy of Z2M config (must be synced to container via SSH)
- `zigbee-devices-backup.json` — device inventory backup

## Device Naming Convention

Format: `{protocol}-{type}{gangs}-{number}`

| Prefix | Type | Example |
|--------|------|---------|
| `Z-MS` | Zigbee motion sensor | Z-MS-01 |
| `Z-TH` | Zigbee temp/humidity | Z-TH-01 |
| `Z-PS` | Zigbee presence sensor | Z-PS-01 |
| `Z-BTN` | Zigbee single button | Z-BTN-01 |
| `Z-RC4` | Zigbee 4-button remote | Z-RC4-01 |
| `Z-KNB` | Zigbee smart knob | Z-KNB-01 |
| `Z-SW1G` | Zigbee 1-gang switch | Z-SW1G-01 |
| `Z-SW2G` | Zigbee 2-gang switch | Z-SW2G-01 |
| `Z-SW3G` | Zigbee 3-gang switch | Z-SW3G-01 |
| `Z-PLG` | Zigbee smart plug | Z-PLG-01 |
| `Z-DR` | Zigbee door sensor | Z-DR-01 |
| `Z-CRT` | Zigbee curtain robot | Z-CRT-01 |
| `Z-RPT` | Zigbee repeater | Z-RPT-01 |
| `W-SW1G` | WiFi 1-gang switch | W-SW1G-01 |

- Protocol: `Z-` (Zigbee), `W-` (WiFi)
- Names are location-independent so devices can be moved freely
- Sequential numbers per type (01, 02, ...)
- Physical labels are stuck on each device

## Adding Zigbee Devices

Use MQTT via Python (`/home/aziz/.pyenv/versions/3.8.20/bin/python3` + `paho.mqtt.client`).

1. **Enable permit join**: publish `{"value": true, "time": 254}` to `zigbee2mqtt/bridge/request/permit_join`
2. **User pairs device** (put in pairing mode)
3. **Check new device**: subscribe to `zigbee2mqtt/bridge/devices`, look for unnamed devices (friendly_name = IEEE address)
4. **Rename**: publish `{"from": "<ieee>", "to": "<name>"}` to `zigbee2mqtt/bridge/request/device/rename`
5. **Re-enable permit join** after each rename (it expires)

## Creating Light Helpers (Switch as X)

When a switch (plug/relay) controls a light, use HA's **Switch as X** helper to expose it as a `light` entity. Do NOT modify Z2M config for this.

1. **Start config flow** (REST API):
   ```
   POST /api/config/config_entries/flow
   {"handler": "switch_as_x", "show_advanced_options": false}
   ```
2. **Submit flow** with the returned `flow_id`:
   ```
   POST /api/config/config_entries/flow/{flow_id}
   {"entity_id": "switch.xxx", "target_domain": "light", "invert": false}
   ```
3. **Rename and label** via WebSocket API (`config/entity_registry/update`)

## HA API Access

- REST API: `Authorization: Bearer $HA_TOKEN` header
- WebSocket: `ws://10.0.0.51:8123/api/websocket`, authenticate with `{"type": "auth", "access_token": TOKEN}`
- Python websocket library: `/home/aziz/.pyenv/versions/3.8.20/bin/python3` with `websocket-client`
- Use WebSocket for: entity registry updates, label management, area assignments
- Use REST API for: state queries, config flows (Switch as X)

## Labels

Labels are managed via WebSocket (`config/label_registry/create`, then `config/entity_registry/update` with `labels` array).

Current labels: `grow_light`, `ambiance_light`
