#!/bin/bash
#
# scan-workspaces.sh - Automatic workspace discovery for Infrastructure-Terrakube
#
# Scans for directories with main.tf files and outputs workspace definitions
# Only creates workspaces for directories that contain Terraform configurations
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_MARKER="${1:-main.tf}" # Default: main.tf, override with first arg

# Python version (preferred - more robust)
if command -v python3 &>/dev/null; then
	exec python3 -c "
import json, os, sys

root = '$SCRIPT_DIR'
marker = '$WORKSPACE_MARKER'
result = {}

for category in ['cluster', 'services', 'servers']:
    cat_dir = os.path.join(root, category)
    if not os.path.isdir(cat_dir):
        continue
    
    for entry in sorted(os.listdir(cat_dir)):
        entry_path = os.path.join(cat_dir, entry)
        if not os.path.isdir(entry_path):
            continue
        
        # Check for workspace marker file (main.tf by default)
        marker_path = os.path.join(entry_path, marker)
        if not os.path.isfile(marker_path):
            continue  # Skip directories without marker file
        
        key = f'{category}-{entry}'
        folder = f'{category}/{entry}'
        
        # Read description from .description file if it exists
        desc_file = os.path.join(entry_path, '.description')
        if os.path.isfile(desc_file):
            with open(desc_file) as f:
                description = f.readline().strip()
        else:
            description = f'{category.capitalize()} workspace: {entry}'
        
        result[key] = json.dumps({'folder': folder, 'description': description})

print(json.dumps(result))
"
fi

# Fallback: shell-only version (if python3 not available)
first=true
echo -n "{"
for category in cluster services servers; do
	category_dir="$SCRIPT_DIR/$category"
	[ -d "$category_dir" ] || continue

	for dir in "$category_dir"/*/; do
		[ -d "$dir" ] || continue

		# Check for workspace marker file
		if [ ! -f "$dir$WORKSPACE_MARKER" ]; then
			continue # Skip if no marker file
		fi

		name="$(basename "$dir")"
		key="${category}-${name}"
		folder="$category/$name"

		# Read description
		desc_file="$dir.description"
		if [ -f "$desc_file" ]; then
			description="$(head -1 "$desc_file")"
		else
			description="$(echo "$category" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}') workspace: $name"
		fi

		$first || echo -n ","
		first=false
		printf '"%s":"{\\"folder\\":\\"%s\\",\\"description\\":\\"%s\\"}"' "$key" "$folder" "$description"
	done
done
echo "}"
