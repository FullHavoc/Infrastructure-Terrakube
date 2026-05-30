#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."

if command -v python3 &>/dev/null; then
	exec python3 -c "
import json, os

root = '$ROOT_DIR'
result = {}
for category in ['cluster', 'services', 'servers', 'clients']:
    cat_dir = os.path.join(root, category)
    if not os.path.isdir(cat_dir):
        continue
    for entry in sorted(os.listdir(cat_dir)):
        entry_path = os.path.join(cat_dir, entry)
        if not os.path.isdir(entry_path):
            continue
        key = f'{category}-{entry}'
        folder = f'terrakube/{category}/{entry}'
        desc_file = os.path.join(entry_path, '.description')
        if os.path.isfile(desc_file):
            with open(desc_file) as f:
                description = f.readline().strip()
        else:
            description = f'Managed workspace for {category} {entry}'
        result[key] = json.dumps({'folder': folder, 'description': description})

print(json.dumps(result))
"
fi

# Fallback: shell-only JSON construction
first=true
echo -n "{"
for category in cluster services servers clients; do
	category_dir="$ROOT_DIR/$category"
	[ -d "$category_dir" ] || continue
	for dir in "$category_dir"/*/; do
		[ -d "$dir" ] || continue
		name="$(basename "$dir")"
		key="${category}-${name}"
		folder="terrakube/$category/$name"
		# shellcheck disable=SC2015
		desc_file="$dir.description"
		if [ -f "$desc_file" ]; then
			description="$(head -1 "$desc_file")"
		else
			description="Managed workspace for $category $name"
		fi
		$first || echo -n ","
		first=false
		printf '"%s":"{\\"folder\\":\\"%s\\",\\"description\\":\\"%s\\"}"' "$key" "$folder" "$description"
	done
done
echo "}"
