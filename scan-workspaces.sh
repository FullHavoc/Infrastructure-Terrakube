#!/usr/bin/env bash
#
# Automatic Terraform Workspace Discovery
#
# Scans repository directories and creates Terrakube workspaces ONLY where
# Terraform configurations exist (presence of main.tf or other marker files).
#
# Inspired by pscloudops/terraform-infrastructure/v4 pattern:
# - Empty directories → no workspace
# - Add main.tf → workspace auto-created
# - Remove main.tf → workspace auto-destroyed
#
# Usage: ./scan-workspaces.sh [marker-file]
#   marker-file: File to look for (default: main.tf)
#
# Output: JSON mapping workspace keys to config
#   {"services-monitoring": "{\"folder\":\"services/monitoring\",\"description\":\"...\"}"}

set -euo pipefail

# Configuration
MARKER_FILE="${1:-main.tf}" # What file indicates a workspace exists
CATEGORIES=("cluster" "services" "servers" "clients")
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Python-based implementation (preferred)
if command -v python3 &>/dev/null; then
	python3 - "$MARKER_FILE" "${CATEGORIES[@]}" <<'EOF'
import sys
import os
import json
from pathlib import Path

def scan_workspaces(marker_file, categories):
    """Scan directories and find workspaces with Terraform configs."""
    workspaces = {}
    script_dir = Path(__file__).parent.resolve() if hasattr(Path(__file__), 'parent') else Path.cwd()
    
    for category in categories:
        category_path = script_dir / category
        if not category_path.exists():
            continue
            
        # Find all subdirectories that contain the marker file
        for item in category_path.iterdir():
            if not item.is_dir():
                continue
                
            # Check if this directory has a Terraform configuration
            marker_path = item / marker_file
            if not marker_path.exists():
                # Skip directories without Terraform configs
                continue
            
            workspace_name = item.name
            workspace_key = f"{category}-{workspace_name}"
            folder = f"{category}/{workspace_name}"
            
            # Try to read description from .description file
            description_file = item / ".description"
            if description_file.exists():
                try:
                    description = description_file.read_text().strip()
                except:
                    description = f"Terraform configuration for {workspace_name}"
            else:
                # Generate description from directory name
                description = f"Terraform configuration for {workspace_name.replace('-', ' ').replace('_', ' ').title()}"
            
            # Store workspace config as JSON string (Terraform external data source requirement)
            workspace_config = {
                "folder": folder,
                "description": description
            }
            workspaces[workspace_key] = json.dumps(workspace_config)
    
    return workspaces

if __name__ == "__main__":
    marker_file = sys.argv[1] if len(sys.argv) > 1 else "main.tf"
    categories = sys.argv[2:] if len(sys.argv) > 2 else ["cluster", "services", "servers", "clients"]
    
    workspaces = scan_workspaces(marker_file, categories)
    
    # Output as JSON (Terraform external data source format)
    print(json.dumps(workspaces, indent=2))
EOF
	exit 0
fi

# Fallback: Shell-based implementation
>&2 echo "Warning: python3 not found, using shell fallback (slower)"

declare -A workspaces

for category in "${CATEGORIES[@]}"; do
	category_path="$BASE_DIR/$category"

	# Skip if category directory doesn't exist
	[[ -d "$category_path" ]] || continue

	# Find directories containing the marker file
	while IFS= read -r -d '' workspace_dir; do
		workspace_name=$(basename "$workspace_dir")
		workspace_key="${category}-${workspace_name}"
		folder="${category}/${workspace_name}"

		# Read description from .description file if it exists
		description_file="$workspace_dir/.description"
		if [[ -f "$description_file" ]]; then
			description=$(cat "$description_file" | tr -d '\n')
		else
			# Generate description from directory name
			description="Terraform configuration for $(echo "$workspace_name" | tr '-_' ' ' | sed 's/\b\(.\)/\u\1/g')"
		fi

		# Store workspace config as JSON string
		workspace_config=$(jq -n \
			--arg folder "$folder" \
			--arg description "$description" \
			'{folder: $folder, description: $description}')

		workspaces["$workspace_key"]="$workspace_config"
	done < <(find "$category_path" -mindepth 1 -maxdepth 1 -type d -exec test -f "{}/$MARKER_FILE" \; -print0)
done

# Output as JSON
echo "{"
first=true
for key in "${!workspaces[@]}"; do
	if [[ "$first" == "true" ]]; then
		first=false
	else
		echo ","
	fi
	# Escape the JSON value (already valid JSON string)
	printf '  "%s": %s' "$key" "$(echo "${workspaces[$key]}" | jq -c '.')"
done
echo ""
echo "}"
