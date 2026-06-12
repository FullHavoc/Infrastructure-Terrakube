# ── Locals ────────────────────────────────────────────────────────────────────

locals {
  ssh_host = "k3sworkervm1.rollet.family"

  packages = [
    "btop",
    "curl",
    "git",
    "htop",
    "nfs-common",
    "unattended-upgrades",
    "vim",
  ]

  lan_subnet = "192.168.144.0/24"

  auto_reboot_enabled = true
  auto_reboot_time    = "02:00"

  unattended_upgrades_config = <<-EOT
    // Managed by Terraform — do not edit manually
    Unattended-Upgrade::Allowed-Origins {
      "$${distro_id}:$${distro_codename}";
      "$${distro_id}:$${distro_codename}-security";
      "$${distro_id}ESMApps:$${distro_codename}-apps-security";
      "$${distro_id}ESM:$${distro_codename}-infra-security";
    };
    Unattended-Upgrade::Package-Blacklist {};
    Unattended-Upgrade::DevRelease "auto";
    Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
    Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
    Unattended-Upgrade::Automatic-Reboot "${tostring(local.auto_reboot_enabled)}";
    Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
    Unattended-Upgrade::Automatic-Reboot-Time "${local.auto_reboot_time}";
  EOT
}

# ── Packages ──────────────────────────────────────────────────────────────────

resource "null_resource" "packages" {
  triggers = {
    packages = join(",", sort(local.packages))
  }

  connection {
    type        = "ssh"
    host        = local.ssh_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -qq",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ${join(" ", sort(local.packages))}",
    ]
  }
}

# ── UFW ───────────────────────────────────────────────────────────────────────

resource "null_resource" "ufw" {
  depends_on = [null_resource.packages]

  triggers = {
    lan_subnet = local.lan_subnet
  }

  connection {
    type        = "ssh"
    host        = local.ssh_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo ufw default deny incoming",
      "sudo ufw default allow outgoing",
      "sudo ufw allow 22/tcp comment 'SSH'",
      "sudo ufw --force enable",
    ]
  }
}

# ── Unattended upgrades ───────────────────────────────────────────────────────

resource "null_resource" "unattended_upgrades" {
  depends_on = [null_resource.packages]

  triggers = {
    auto_reboot_enabled = tostring(local.auto_reboot_enabled)
    auto_reboot_time    = local.auto_reboot_time
  }

  connection {
    type        = "ssh"
    host        = local.ssh_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "file" {
    content     = local.unattended_upgrades_config
    destination = "/tmp/50unattended-upgrades.terrakube"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/50unattended-upgrades.terrakube /etc/apt/apt.conf.d/50unattended-upgrades",
      "sudo chmod 644 /etc/apt/apt.conf.d/50unattended-upgrades",
      "sudo systemctl enable --now unattended-upgrades",
    ]
  }
}

# ── Authorized keys ───────────────────────────────────────────────────────────

resource "null_resource" "authorized_keys" {
  triggers = {
    keys_hash = sha256(join("\n", var.authorized_keys))
  }

  connection {
    type        = "ssh"
    host        = local.ssh_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "file" {
    content     = join("\n", var.authorized_keys)
    destination = "/tmp/authorized_keys.terrakube"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh && chmod 700 ~/.ssh",
      "mv /tmp/authorized_keys.terrakube ~/.ssh/authorized_keys",
      "chmod 600 ~/.ssh/authorized_keys",
    ]
  }
}
