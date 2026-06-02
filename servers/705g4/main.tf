# ── Locals ────────────────────────────────────────────────────────────────────

locals {
  # ── Connection ──────────────────────────────────────────────────────────────
  ssh_host = "705g4.rollet.family"

  # ── Packages — standard Ubuntu repos ────────────────────────────────────────
  packages_standard = [
    "btop",
    "curl",
    "etcd-client",
    "gnupg2",
    "nfs-common",
    "open-iscsi",
    "radeontop",
    "software-properties-common",
    "unattended-upgrades",
    "wget",
    "wpasupplicant",
  ]

  # ── Packages — AMD ROCm repo (repo must be configured first) ─────────────────
  packages_rocm = [
    "libdrm-amdgpu1",
    "mesa-utils",
    "mesa-vulkan-drivers",
    "rocm-hip-runtime",
    "rocminfo",
    "rocm-opencl-runtime",
    "rocm-smi",
    "xserver-xorg-video-amdgpu",
  ]

  # ── ROCm repo ────────────────────────────────────────────────────────────────
  rocm_repo_key_url = "https://repo.radeon.com/rocm/rocm.gpg.key"
  rocm_repo_line    = "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.3 noble main"

  # ── Unattended upgrades ─────────────────────────────────────────────────────
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

# ── Standard packages ─────────────────────────────────────────────────────────

resource "null_resource" "packages_standard" {
  triggers = {
    packages = join(",", sort(local.packages_standard))
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
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ${join(" ", sort(local.packages_standard))}",
    ]
  }
}

# ── ROCm repo + packages ───────────────────────────────────────────────────────
# Adds AMD ROCm 6.3 apt repo and installs GPU compute packages.
# The HP ProDesk 705 G4 has an AMD Ryzen APU (Vega graphics) used for GPU compute.

resource "null_resource" "rocm" {
  depends_on = [null_resource.packages_standard]

  triggers = {
    repo_line = local.rocm_repo_line
    packages  = join(",", sort(local.packages_rocm))
  }

  connection {
    type        = "ssh"
    host        = local.ssh_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/apt/keyrings",
      "curl -fsSL ${local.rocm_repo_key_url} | sudo gpg --dearmor --yes -o /etc/apt/keyrings/rocm.gpg",
      "echo '${local.rocm_repo_line}' | sudo tee /etc/apt/sources.list.d/rocm.list > /dev/null",
      "sudo apt-get update -qq",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ${join(" ", sort(local.packages_rocm))}",
    ]
  }
}

# ── iSCSI cleanup ─────────────────────────────────────────────────────────────
# Remove stale Longhorn PVC node records left from the decommissioned local
# K3s cluster. No sessions are active; logout is a safe no-op.

resource "null_resource" "iscsi_cleanup" {
  triggers = {
    run_once = "2026-06-02"
  }

  connection {
    type        = "ssh"
    host        = local.ssh_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo iscsiadm -m node --logoutall=all 2>/dev/null || true",
      "sudo iscsiadm -m node -o delete 2>/dev/null || true",
    ]
  }
}

# ── UFW ───────────────────────────────────────────────────────────────────────
# SSH allowed globally. No NFS server role on this machine.

resource "null_resource" "ufw" {
  depends_on = [null_resource.packages_standard]

  triggers = {
    rules = "ssh-only"
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
  depends_on = [null_resource.packages_standard]

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
