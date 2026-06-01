# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  WORKSPACE MARKER                                                            ║
# ║  This file is the source of truth for this Terrakube workspace.             ║
# ║  Deleting it removes the workspace from Terrakube and triggers destruction  ║
# ║  of all resources managed by this configuration.                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# description: Dell PowerEdge Ubuntu Server — packages, NFS mounts/exports, UFW, unattended-upgrades, authorized keys

# ── Workspace variables ───────────────────────────────────────────────────────
# Set in the Terrakube workspace (sourced from Doppler) and injected at plan/apply time.

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "ED25519 private key for SSH access (stored in Doppler as TERRAKUBE_SSH_PRIVATE_KEY)"
}

variable "authorized_keys" {
  type        = list(string)
  sensitive   = true
  description = "SSH public keys to write to ~/.ssh/authorized_keys"
  default     = []
}
