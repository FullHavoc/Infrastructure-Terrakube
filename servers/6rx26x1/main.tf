terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "remote" {}
}

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

variable "packages" {
  type        = list(string)
  description = "APT packages to ensure are installed"
  default     = ["htop", "vim", "git", "curl", "unattended-upgrades"]
}

resource "null_resource" "packages" {
  triggers = {
    packages = join(",", sort(var.packages))
  }

  connection {
    type        = "ssh"
    host        = var.ssh_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -qq",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ${join(" ", var.packages)}",
    ]
  }
}

resource "null_resource" "unattended_upgrades" {
  depends_on = [null_resource.packages]

  connection {
    type        = "ssh"
    host        = var.ssh_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl enable --now unattended-upgrades",
    ]
  }
}
