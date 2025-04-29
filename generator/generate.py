#! /usr/bin/env python3
from jinja2 import Environment, FileSystemLoader
import os, re

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Config
rooms = [
    "Living Room",
    "Bedroom",
    "Kitchen",
    "Middle Room"
]

config_dir = "config"

# Setup
env = Environment(loader=FileSystemLoader(os.path.join(BASE_DIR, "generator", "templates")),
                  keep_trailing_newline=True,
                  trim_blocks=True,
                  lstrip_blocks=True)


output_dir = os.path.join(config_dir, "sensors", "template")
os.makedirs(output_dir, exist_ok=True)

# Generate overall files
filename = os.path.join(output_dir, "overall.yaml")
template = env.get_template("overall-sensors-template.j2")
with open(filename, "w") as f:
    f.write(template.render())

template = env.get_template("sensors-template.j2")
# Generate files
for room in rooms:
    slug = re.sub(r"[^\w\s-]", "", room).lower().replace(" ", "-")
    filename = os.path.join(output_dir, f"{slug}.yaml")

    with open(filename, "w") as f:
        f.write(template.render(room=room))

print(f"Generated {len(rooms)} files in {output_dir}/")
