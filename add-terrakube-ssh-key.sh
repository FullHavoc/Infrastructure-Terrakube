#!/usr/bin/env bash

# Adds the Terrakube SSH public key to a target server's authorized_keys.
# The key is pulled from Doppler (matrix-homelab/hetzner → TRUENAS_TERRAKUBE_SSH_KEY).
# Usage: add-terrakube-ssh-key.sh [user@]host [...]

set +e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOPPLER_PROJECT="matrix-homelab"
DOPPLER_CONFIG="hetzner"
DOPPLER_SECRET="TRUENAS_TERRAKUBE_SSH_KEY"

# --- Validate dependencies ---
if ! command -v doppler &>/dev/null; then
	echo -e "${RED}Error: doppler CLI not found — install it from https://docs.doppler.com/docs/cli${NC}"
	exit 1
fi

if [[ $# -eq 0 ]]; then
	echo "Usage: $(basename "$0") [user@]host [...]"
	echo ""
	echo "  Adds the Terrakube SSH public key to one or more target servers."
	echo "  Key source: Doppler $DOPPLER_PROJECT/$DOPPLER_CONFIG → $DOPPLER_SECRET"
	echo ""
	echo "Examples:"
	echo "  $(basename "$0") havoc@6rx26x1.rollet.family"
	echo "  $(basename "$0") root@192.168.1.50"
	echo "  $(basename "$0") havoc@host1.rollet.family root@host2.rollet.family"
	exit 0
fi

# --- Fetch and decode private key from Doppler, derive public key ---
echo "Fetching Terrakube SSH key from Doppler ($DOPPLER_PROJECT/$DOPPLER_CONFIG)..."

PRIVKEY_FILE=$(mktemp)
chmod 600 "$PRIVKEY_FILE"

cleanup() {
	rm -f "$PRIVKEY_FILE"
}
trap cleanup EXIT

if ! doppler secrets get "$DOPPLER_SECRET" \
	--project "$DOPPLER_PROJECT" \
	--config "$DOPPLER_CONFIG" \
	--plain 2>&1 | base64 -d > "$PRIVKEY_FILE"; then
	echo -e "${RED}Error: Failed to fetch $DOPPLER_SECRET from Doppler${NC}"
	exit 1
fi

PUBKEY=$(ssh-keygen -y -f "$PRIVKEY_FILE" 2>&1)
if [[ $? -ne 0 ]]; then
	echo -e "${RED}Error: Failed to derive public key from private key${NC}"
	echo "$PUBKEY"
	exit 1
fi

echo -e "${GREEN}Public key:${NC} $PUBKEY"
echo ""
echo -e "${YELLOW}Targets:${NC}"
for target in "$@"; do
	echo "  - $target"
done
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo "Aborted."
	exit 0
fi

check_host_reachable() {
	local hostname
	hostname=$(echo "$1" | cut -d'@' -f2)

	if command -v host &>/dev/null; then
		if ! host "$hostname" &>/dev/null; then
			return 1
		fi
	elif command -v getent &>/dev/null; then
		if ! getent hosts "$hostname" &>/dev/null; then
			return 1
		fi
	fi

	timeout 5 bash -c "cat < /dev/null > /dev/tcp/$hostname/22" 2>/dev/null
}

add_terrakube_key() {
	local target=$1
	local hostname
	hostname=$(echo "$target" | cut -d'@' -f2)

	echo -e "\n${YELLOW}Adding Terrakube key to $target...${NC}"

	echo "  Checking connectivity..."
	if ! check_host_reachable "$target"; then
		echo -e "${YELLOW}⚠ $hostname is unreachable — skipping${NC}"
		return 2
	fi

	# Check if key is already present before touching authorized_keys
	local already_present
	already_present=$(ssh \
		-o ConnectTimeout=10 \
		-o ConnectionAttempts=1 \
		-o BatchMode=no \
		"$target" \
		"grep -qF '$PUBKEY' ~/.ssh/authorized_keys 2>/dev/null && echo yes || echo no" 2>&1)

	if [[ "$already_present" == "yes" ]]; then
		echo -e "${GREEN}✓ Key already present on $target${NC}"
		return 0
	fi

	local output
	output=$(ssh \
		-o ConnectTimeout=10 \
		-o ConnectionAttempts=1 \
		-o BatchMode=no \
		"$target" \
		"mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" 2>&1)
	local exit_code=$?

	if [[ $exit_code -eq 0 ]]; then
		echo -e "${GREEN}✓ Key added to $target${NC}"
		return 0
	else
		if echo "$output" | grep -qi "connection.*refused\|connection.*timed out\|no route to host\|could not resolve hostname"; then
			echo -e "${YELLOW}⚠ Could not connect to $target${NC}"
			return 2
		elif echo "$output" | grep -qi "permission denied\|authentication failed"; then
			echo -e "${RED}✗ Authentication failed for $target — check credentials${NC}"
			return 1
		else
			echo -e "${RED}✗ Failed to add key to $target${NC}"
			echo "$output" | tail -n 3
			return 1
		fi
	fi
}

SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0
declare -a FAILED_HOSTS
declare -a SKIPPED_HOSTS

for target in "$@"; do
	add_terrakube_key "$target"
	result=$?

	if [[ $result -eq 0 ]]; then
		((SUCCESS_COUNT++))
	elif [[ $result -eq 2 ]]; then
		((SKIPPED_COUNT++))
		SKIPPED_HOSTS+=("$target")
	else
		((FAILED_COUNT++))
		FAILED_HOSTS+=("$target")
	fi
done

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "  ${GREEN}✓ Successful: $SUCCESS_COUNT${NC}"
echo -e "  ${YELLOW}⚠ Skipped (unreachable): $SKIPPED_COUNT${NC}"
echo -e "  ${RED}✗ Failed: $FAILED_COUNT${NC}"

if [[ $SKIPPED_COUNT -gt 0 ]]; then
	echo -e "\n${YELLOW}Skipped (unreachable):${NC}"
	for host in "${SKIPPED_HOSTS[@]}"; do
		echo "  - $host"
	done
fi

if [[ $FAILED_COUNT -gt 0 ]]; then
	echo -e "\n${RED}Failed:${NC}"
	for host in "${FAILED_HOSTS[@]}"; do
		echo "  - $host"
	done
fi

echo -e "${GREEN}========================================${NC}"
