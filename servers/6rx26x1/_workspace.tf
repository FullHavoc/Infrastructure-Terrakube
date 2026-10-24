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

variable "nfs_client_subnet" {
  type        = string
  description = "LAN CIDR allowed to mount NFS exports (workspace variable — set directly in this Terrakube workspace, not committed here)"

  validation {
    condition = (
      can(cidrhost(var.nfs_client_subnet, 0)) &&
      can(regex("^(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.)", var.nfs_client_subnet))
    )
    error_message = "nfs_client_subnet must be a valid CIDR within a private range (RFC 1918: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) — refusing anything broader (e.g. 0.0.0.0/0) to prevent granting NFS mount access beyond the home LAN."
  }
}
