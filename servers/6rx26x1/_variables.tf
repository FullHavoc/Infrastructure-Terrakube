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
