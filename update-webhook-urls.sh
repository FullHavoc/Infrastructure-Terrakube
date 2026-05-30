#!/bin/bash

# GitHub webhook IDs
PUSH_WEBHOOK_ID=633762939
PR_WEBHOOK_ID=633762945

# Correct v1 webhook URL
WEBHOOK_URL="https://api.terrakube.rollet.family/webhook/v1/7beea389-be93-4ac7-9f66-18042b0eec8f"

# Get GitHub token
GITHUB_TOKEN=$(doppler secrets get GITHUB_PAT --plain)

# Update push webhook
echo "Updating push webhook..."
curl -X PATCH \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/FullHavoc/Infrastructure-Terrakube/hooks/${PUSH_WEBHOOK_ID}" \
  -d "{\"config\":{\"url\":\"${WEBHOOK_URL}\",\"content_type\":\"json\"}}"

echo -e "\n\nUpdating pull_request webhook..."
curl -X PATCH \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/FullHavoc/Infrastructure-Terrakube/hooks/${PR_WEBHOOK_ID}" \
  -d "{\"config\":{\"url\":\"${WEBHOOK_URL}\",\"content_type\":\"json\"}}"
