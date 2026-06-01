#!/bin/bash
#
# scan-workspaces.sh - Automatic workspace discovery for Infrastructure-Terrakube
#
# Scans for directories with _workspace.tf files and outputs workspace definitions.
# _workspace.tf is the source of truth for a workspace — deleting it removes the
# workspace from Terrakube. Description is read from the "# description:" line in
# _workspace.tf, with fallback to a .description file.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_MARKER="${1:-_workspace.tf}" # Default: _workspace.tf, override with first arg

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

        # _workspace.tf is the workspace marker — its presence defines this as a workspace
        marker_path = os.path.join(entry_path, marker)
        if not os.path.isfile(marker_path):
            continue

        key = f'{category}-{entry}'
        folder = f'{category}/{entry}'

        # Read description from '# description:' line in _workspace.tf
        description = f'{category.capitalize()} workspace: {entry}'
        with open(marker_path) as f:
            for line in f:
                stripped = line.strip()
                if stripped.startswith('# description:'):
                    description = stripped[len('# description:'):].strip()
                    break
            else:
                # Fall back to .description file if no description line found
                desc_file = os.path.join(entry_path, '.description')
                if os.path.isfile(desc_file):
                    with open(desc_file) as df:
                        description = df.readline().strip()

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

		# _workspace.tf is the workspace marker
		if [ ! -f "$dir$WORKSPACE_MARKER" ]; then
			continue
		fi

		name="$(basename "$dir")"
		key="${category}-${name}"
		folder="$category/$name"

		# Read description from '# description:' line in _workspace.tf
		description=""
		while IFS= read -r line; do
			case "$line" in
				"# description:"*)
					description="${line#"# description:"}"
					description="${description# }"
					break
					;;
			esac
		done < "$dir$WORKSPACE_MARKER"

		# Fall back to .description file
		if [ -z "$description" ]; then
			desc_file="$dir.description"
			if [ -f "$desc_file" ]; then
				description="$(head -1 "$desc_file")"
			else
				description="$(echo "$category" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}') workspace: $name"
			fi
		fi

		$first || echo -n ","
		first=false
		printf '"%s":"{\\"folder\\":\\"%s\\",\\"description\\":\\"%s\\"}"' "$key" "$folder" "$description"
	done
done
echo "}"
