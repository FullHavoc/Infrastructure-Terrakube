#!/usr/bin/env bash

# Sets up terraform.tfvars and backend.hcl for a new machine.
# Pulls the Terrakube PAT token from Doppler; all other values are static.
# Usage: ./setup-tfvars.sh

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOPPLER_PROJECT="matrix-homelab"
DOPPLER_CONFIG="hetzner"

# --- Validate dependencies ---
if ! command -v doppler &>/dev/null; then
	echo -e "${RED}Error: doppler CLI not found${NC}"
	echo "Install it from: https://docs.doppler.com/docs/cli"
	exit 1
fi

# --- Guard against overwriting existing files ---
TFVARS="$SCRIPT_DIR/terraform.tfvars"
BACKEND="$SCRIPT_DIR/backend.hcl"
SKIP_TFVARS=""
SKIP_BACKEND=""

if [[ -f "$TFVARS" ]]; then
	echo -e "${YELLOW}Warning: $TFVARS already exists.${NC}"
	read -p "Overwrite? (y/n) " -n 1 -r || true
	echo ""
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "Skipping terraform.tfvars."
		SKIP_TFVARS=1
	fi
fi

if [[ -f "$BACKEND" ]]; then
	echo -e "${YELLOW}Warning: $BACKEND already exists.${NC}"
	read -p "Overwrite? (y/n) " -n 1 -r || true
	echo ""
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "Skipping backend.hcl."
		SKIP_BACKEND=1
	fi
fi

# --- Fetch PAT token from Doppler ---
echo ""
echo "Fetching TERRAKUBE_PAT_TOKEN from Doppler ($DOPPLER_PROJECT/$DOPPLER_CONFIG)..."

TOKEN=$(doppler secrets get TERRAKUBE_PAT_TOKEN \
	--project "$DOPPLER_PROJECT" \
	--config "$DOPPLER_CONFIG" \
	--plain 2>&1)

if [[ $? -ne 0 || -z "$TOKEN" ]]; then
	echo -e "${RED}Error: Failed to fetch TERRAKUBE_PAT_TOKEN from Doppler${NC}"
	echo "$TOKEN"
	exit 1
fi

echo -e "${GREEN}✓ Token fetched${NC}"

# --- Write terraform.tfvars ---
if [[ -z "$SKIP_TFVARS" ]]; then
	cat >"$TFVARS" <<EOF
# Terrakube Configuration
# This file contains sensitive data and is gitignored

# --- Required Variables ---

# Terrakube instance endpoint
terrakube_endpoint = "https://api.terrakube.rollet.family"

# Terrakube organization name
terrakube_organization = "HomeInfrastructure"

# VCS connection name (for STANDALONE GitHub App)
vcs_name = "Infrastructure-Terrakube"

# Infrastructure repository (THIS repo - points to itself)
infrastructure_repo = "https://github.com/FullHavoc/Infrastructure-Terrakube"

# Terrakube API token
# Get from: Terrakube UI → Settings → Personal Access Tokens
terrakube_token = "$TOKEN"

# --- Optional Variables (overriding defaults) ---

# Git branch to use
infrastructure_branch = "main"

# Prefix for workspace names
workspace_prefix = "home-infrastructure"

# Name of the manager workspace (already exists and was just updated)
manager_workspace_name = "Infrastructure-Terrakube"

# IaC type
iac_type = "terraform"

# Terraform version
iac_version = "1.15.5"

# Branch patterns for webhooks (all branches)
webhook_branches = ["*"]
EOF
	echo -e "${GREEN}✓ Written: $TFVARS${NC}"
fi

# --- Write backend.hcl ---
if [[ -z "$SKIP_BACKEND" ]]; then
	cp "$SCRIPT_DIR/backend.hcl.example" "$BACKEND" || {
		echo -e "${RED}Error: backend.hcl.example not found${NC}"
		exit 1
	}
	echo -e "${GREEN}✓ Written: $BACKEND${NC}"
fi

# --- Handle TF_TOKEN env var ---
# tofu init needs this to authenticate with the Terrakube remote backend.
# It is the same PAT token — derived from the backend hostname.
ENVRC="$SCRIPT_DIR/.envrc"

echo ""
if command -v direnv &>/dev/null; then
	if [[ -f "$ENVRC" ]]; then
		echo -e "${YELLOW}.envrc already exists — not modifying it.${NC}"
	else
		read -p "Write TF_TOKEN to .envrc for direnv? (y/n) " -n 1 -r || true
		echo ""
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			cat >"$ENVRC" <<EOF
export TF_TOKEN_api_terrakube_rollet_family="$TOKEN"
EOF
			echo -e "${GREEN}✓ Written: $ENVRC${NC}"
			direnv allow "$SCRIPT_DIR" || echo -e "${YELLOW}Warning: direnv allow failed${NC}"
			echo -e "${GREEN}✓ direnv allowed${NC}"
		fi
	fi
fi

echo ""
echo -e "${YELLOW}Add the following to your shell session (or .envrc / shell profile):${NC}"
echo ""
# Mask the token - only show first and last 4 characters
TOKEN_MASKED="${TOKEN:0:4}...${TOKEN: -4}"
echo "  export TF_TOKEN_api_terrakube_rollet_family=\"<token_masked:${TOKEN_MASKED}>\""
echo ""
echo -e "${YELLOW}Note: Retrieve the full token from Doppler if needed:${NC}"
echo "  doppler secrets get TERRAKUBE_PAT_TOKEN --project $DOPPLER_PROJECT --config $DOPPLER_CONFIG --plain"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup complete. Next steps:${NC}"
echo "  1. Export the TF_TOKEN variable above (or let direnv handle it)"
echo "  2. tofu init -backend-config=backend.hcl"
echo "  3. tofu plan"
echo -e "${GREEN}========================================${NC}"
