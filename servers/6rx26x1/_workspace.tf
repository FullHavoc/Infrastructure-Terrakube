# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  WORKSPACE MARKER                                                            ║
# ║  This file is the source of truth for this Terrakube workspace.             ║
# ║  Deleting it removes the workspace from Terrakube and triggers destruction  ║
# ║  of all resources managed by this configuration.                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# description: Dell PowerEdge Ubuntu Server — packages, NFS mounts/exports, UFW, unattended-upgrades, authorized keys

# ── Workspace variables ───────────────────────────────────────────────────────
# Global org variables (set once in Terrakube, injected into all workspaces):
#   ssh_private_key — ED25519 private key (sourced from Doppler as TERRAKUBE_SSH_PRIVATE_KEY)
#   ssh_user        — SSH username (havoc)

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "ED25519 private key for SSH access (global org variable)"
}

variable "ssh_user" {
  type        = string
  description = "SSH username (global org variable)"
}

variable "authorized_keys" {
  type        = list(string)
  sensitive   = true
  description = "SSH public keys to write to ~/.ssh/authorized_keys"
  default     = []
}
