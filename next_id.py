#!/usr/bin/env python3
"""Generate the next available device ID for a given Zigbee device type, filling gaps."""

import paho.mqtt.client as mqtt
import json
import re
import sys
import threading

MQTT_HOST = "10.0.0.51"
MQTT_PORT = 1883

# Map new type prefixes to regex patterns that match both old and new naming
# Each entry: new_prefix -> list of regex patterns that extract the device number
TYPE_PATTERNS = {
    "Z-MS":   [r"^Z-MS-(\d+)$", r"^MS(\d+)$"],
    "Z-TH":   [r"^Z-TH-(\d+)$", r"^THS(\d+)$"],
    "Z-PS":   [r"^Z-PS-(\d+)$", r"^PS(\d+)$"],
    "Z-BTN":  [r"^Z-BTN-(\d+)$", r"^SSS(\d+)$"],
    "Z-KNB":  [r"^Z-KNB-(\d+)$", r"^SSK(\d+)$"],
    "Z-RC4":  [r"^Z-RC4-(\d+)$", r"^WB-4G-(\d+)$", r"^WSS(\d+)$"],
    "Z-SW1G": [r"^Z-SW1G-(\d+)$", r"^ZMS(\d+)-1G$"],
    "Z-SW2G": [r"^Z-SW2G-(\d+)$", r"^ZMS(\d+)-2G$", r"^ZSS(\d+)$"],
    "Z-SW3G": [r"^Z-SW3G-(\d+)$", r"^ZSS3G(\d+)$"],
    "Z-PLG":  [r"^Z-PLG-(\d+)$", r"^ZSP(\d+)$"],
    "Z-DR":   [r"^Z-DR-(\d+)$", r"^DS(\d+)$"],
    "Z-CRT":  [r"^Z-CRT-(\d+)$"],
    "Z-RPT":  [r"^Z-RPT-(\d+)$"],
    "W-SW1G": [r"^W-SW1G-(\d+)$"],
}

# Friendly aliases for device types
TYPE_ALIASES = {
    "motion":    "Z-MS",
    "temp":      "Z-TH",
    "humidity":  "Z-TH",
    "presence":  "Z-PS",
    "button":    "Z-BTN",
    "knob":      "Z-KNB",
    "remote":    "Z-RC4",
    "switch1":   "Z-SW1G",
    "switch2":   "Z-SW2G",
    "switch3":   "Z-SW3G",
    "plug":      "Z-PLG",
    "door":      "Z-DR",
    "curtain":   "Z-CRT",
    "repeater":  "Z-RPT",
    "wswitch1":  "W-SW1G",
}


def resolve_type(name):
    """Resolve a type name or alias to a canonical type prefix."""
    upper = name.upper()
    if upper in TYPE_PATTERNS:
        return upper
    lower = name.lower()
    if lower in TYPE_ALIASES:
        return TYPE_ALIASES[lower]
    return None


def get_devices():
    """Fetch device list from Z2M via MQTT."""
    result = []
    done = threading.Event()

    def on_connect(client, userdata, flags, rc):
        client.subscribe("zigbee2mqtt/bridge/devices")

    def on_message(client, userdata, msg):
        result.extend(json.loads(msg.payload))
        done.set()

    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(MQTT_HOST, MQTT_PORT)
    client.loop_start()
    done.wait(timeout=10)
    client.loop_stop()
    client.disconnect()
    return result


def find_used_numbers(devices, device_type):
    """Find all used numbers for a device type."""
    patterns = TYPE_PATTERNS.get(device_type)
    if not patterns:
        return set()

    used = set()
    for dev in devices:
        name = dev.get("friendly_name", "")
        for pattern in patterns:
            m = re.match(pattern, name)
            if m:
                used.add(int(m.group(1)))
                break
    return used


def next_id(device_type, devices=None):
    """Return the next available ID string, filling gaps."""
    if devices is None:
        devices = get_devices()

    used = find_used_numbers(devices, device_type)
    n = 1
    while n in used:
        n += 1
    return f"{device_type}-{n:02d}"


def main():
    if len(sys.argv) < 2:
        print("Usage: next_id.py <type>")
        print(f"\nTypes:   {', '.join(sorted(TYPE_PATTERNS.keys()))}")
        print(f"Aliases: {', '.join(sorted(TYPE_ALIASES.keys()))}")
        sys.exit(1)

    device_type = resolve_type(sys.argv[1])
    if not device_type:
        print(f"Unknown type: {sys.argv[1]}")
        print(f"Types:   {', '.join(sorted(TYPE_PATTERNS.keys()))}")
        print(f"Aliases: {', '.join(sorted(TYPE_ALIASES.keys()))}")
        sys.exit(1)

    print(next_id(device_type))


if __name__ == "__main__":
    main()
