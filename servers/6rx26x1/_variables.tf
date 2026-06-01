# ── Connection ───────────────────────────────────────────────────────────────

variable "ssh_host" {
  type        = string
  description = "SSH hostname or IP of the target server"
}

variable "ssh_user" {
  type        = string
  description = "SSH username on the target server"
}

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "ED25519 private key for SSH access"
}

# ── Packages ─────────────────────────────────────────────────────────────────

variable "packages" {
  type        = list(string)
  description = "APT packages to ensure are installed"
  default = [
    "btop",
    "curl",
    "git",
    "htop",
    "nfs-common",
    "nfs-kernel-server",
    "open-iscsi",
    "unattended-upgrades",
    "vim",
  ]
}

# ── NFS ──────────────────────────────────────────────────────────────────────

variable "nfs_source_host" {
  type        = string
  description = "NFS source server hostname or IP (TrueNAS)"
}

variable "nfs_client_subnet" {
  type        = string
  description = "Subnet allowed to mount NFS exports (also used for UFW LAN rules)"
}

variable "nfs_media_shares" {
  type        = map(string)
  description = "Map of local mount name to NFS source path, e.g. {\"movies\" = \"/mnt/pool/Movies\"}"
  default     = {}
}

variable "nfs_backup_source_path" {
  type        = string
  description = "NFS source path for the k3s-backups mount (empty string to skip)"
  default     = ""
}

# ── SSH authorized keys ───────────────────────────────────────────────────────

variable "authorized_keys" {
  type        = list(string)
  sensitive   = true
  description = "SSH public keys to write to ~/.ssh/authorized_keys"
  default     = []
}

# ── Unattended upgrades ───────────────────────────────────────────────────────

variable "auto_reboot_enabled" {
  type        = bool
  description = "Automatically reboot after security upgrades if /var/run/reboot-required exists"
  default     = true
}

variable "auto_reboot_time" {
  type        = string
  description = "Time to perform automatic reboot (24h HH:MM)"
  default     = "02:00"
}
