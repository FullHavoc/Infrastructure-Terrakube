#!/bin/bash
# NOTE: Terrakube now manages the GitHub webhook automatically via the webhook_v2 resource.
# This script is kept for reference but is no longer needed for normal operation.
#
# The active webhook on FullHavoc/Infrastructure-Terrakube is managed by Terrakube
# and points to: https://api.terrakube.rollet.family/webhook/v2/<id>
#
# To see the current webhook URL, run:
#   tofu output manager_webhook_url
#
# To see the active GitHub webhook:
#   gh api repos/FullHavoc/Infrastructure-Terrakube/hooks | jq '[.[] | {id, events, url: .config.url}]'

set -euo pipefail

WEBHOOK_URL=$(tofu output -raw manager_webhook_url 2>/dev/null)

if [[ -z "$WEBHOOK_URL" ]]; then
  echo "ERROR: Could not determine webhook URL. Run 'tofu apply' first, or pass the URL as an argument." >&2
  exit 1
fi

echo "Current Terrakube webhook URL: $WEBHOOK_URL"
echo ""
echo "GitHub webhook is managed automatically by Terrakube."
echo "Current GitHub webhooks:"
gh api repos/FullHavoc/Infrastructure-Terrakube/hooks | jq '[.[] | {id, events, url: .config.url}]'
