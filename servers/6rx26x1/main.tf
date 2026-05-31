terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "remote" {}
}

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "ED25519 private key for havoc@6rx26x1.rollet.family"
}

variable "packages" {
  type        = list(string)
  description = "APT packages to ensure are installed"
  default     = ["htop", "vim", "git", "curl", "unattended-upgrades"]
}

locals {
  host = "192.168.144.25"
  user = "havoc"
}

resource "null_resource" "packages" {
  triggers = {
    packages = join(",", sort(var.packages))
  }

  connection {
    type        = "ssh"
    host        = local.host
    user        = local.user
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
    host        = local.host
    user        = local.user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl enable --now unattended-upgrades",
    ]
  }
}
