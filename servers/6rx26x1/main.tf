# ── Locals ────────────────────────────────────────────────────────────────────

locals {
  # ── Connection ──────────────────────────────────────────────────────────────
  ssh_host = "6rx26x1.rollet.family"

  # ── Packages ────────────────────────────────────────────────────────────────
  packages = [
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

  # ── NFS ─────────────────────────────────────────────────────────────────────
  nfs_source_host        = "truenas.rollet.family"
  nfs_client_subnet      = "192.168.144.0/24"
  nfs_backup_source_path = "/mnt/MassStorage/k3s-backups"

  nfs_media_shares = {
    books     = "/mnt/MassStorage/Media/Books"
    downloads = "/mnt/MassStorage/Media/downloads"
    movies    = "/mnt/MassStorage/Media/Movies"
    music     = "/mnt/MassStorage/Media/Music"
    tv        = "/mnt/MassStorage/Media/TV"
  }

  # ── Unattended upgrades ─────────────────────────────────────────────────────
  auto_reboot_enabled = true
  auto_reboot_time    = "02:00"

  # ── Derived ─────────────────────────────────────────────────────────────────
  sorted_share_names = sort(keys(local.nfs_media_shares))

  # /etc/exports — re-exports TrueNAS shares to LAN clients
  nfs_exports_content = join("\n", concat(
    ["# Managed by Terraform — do not edit manually"],
    [for i, name in local.sorted_share_names :
      "/mnt/truenas/${name}\t${local.nfs_client_subnet}(rw,sync,no_subtree_check,no_root_squash,fsid=${i + 1})"
    ],
    ["/mnt/k3s-backups\t${local.nfs_client_subnet}(ro,sync,no_subtree_check,no_root_squash,fsid=100)"],
    [""]
  ))

  # fstab block — mounts from NFS source host into this server
  nfs_fstab_block = join("\n", concat(
    ["# TERRAKUBE-NFS-BEGIN — do not edit manually"],
    [for name, path in local.nfs_media_shares :
      "${local.nfs_source_host}:${path} /mnt/truenas/${name} nfs defaults,_netdev,nofail 0 0"
    ],
    ["${local.nfs_source_host}:${local.nfs_backup_source_path} /mnt/k3s-backups nfs defaults,_netdev,nofail 0 0"],
    ["# TERRAKUBE-NFS-END", ""]
  ))

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

# ── iSCSI cleanup ─────────────────────────────────────────────────────────────
# Remove stale Longhorn PVC node records left from the decommissioned local
# K3s cluster. No sessions are active; logout is a safe no-op.

resource "null_resource" "iscsi_cleanup" {
  triggers = {
    run_once = "2026-06-01"
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

# ── NFS source mounts ─────────────────────────────────────────────────────────
# Mounts TrueNAS shares onto this server so they can be re-exported.
# Uses a comment-delimited block in /etc/fstab for idempotent management.

resource "null_resource" "nfs_source_mounts" {
  depends_on = [null_resource.packages]

  triggers = {
    source_host   = local.nfs_source_host
    shares        = sha256(jsonencode(local.nfs_media_shares))
    backup_source = local.nfs_backup_source_path
  }

  connection {
    type        = "ssh"
    host        = local.ssh_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = concat(
      ["sudo mkdir -p /mnt/truenas"],
      [for name, _ in local.nfs_media_shares : "sudo mkdir -p /mnt/truenas/${name}"],
      ["sudo mkdir -p /mnt/k3s-backups"],
      ["sudo sed -i '/# TERRAKUBE-NFS-BEGIN/,/# TERRAKUBE-NFS-END/d' /etc/fstab"],
    )
  }

  provisioner "file" {
    content     = local.nfs_fstab_block
    destination = "/tmp/fstab-nfs.terrakube"
  }

  provisioner "remote-exec" {
    inline = [
      "cat /tmp/fstab-nfs.terrakube | sudo tee -a /etc/fstab > /dev/null",
      "rm /tmp/fstab-nfs.terrakube",
      "sudo mount -a 2>&1 | grep -v 'already mounted' || true",
    ]
  }
}

# ── NFS exports ───────────────────────────────────────────────────────────────
# Writes /etc/exports and re-exports to LAN clients.

resource "null_resource" "nfs_exports" {
  depends_on = [null_resource.packages, null_resource.nfs_source_mounts]

  triggers = {
    client_subnet = local.nfs_client_subnet
    shares        = sha256(jsonencode(local.nfs_media_shares))
    backup_source = local.nfs_backup_source_path
  }

  connection {
    type        = "ssh"
    host        = local.ssh_host
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  provisioner "file" {
    content     = local.nfs_exports_content
    destination = "/tmp/exports.terrakube"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/exports.terrakube /etc/exports",
      "sudo chmod 644 /etc/exports",
      "sudo systemctl enable --now nfs-server",
      "sudo exportfs -ra",
    ]
  }
}

# ── UFW ───────────────────────────────────────────────────────────────────────
# Enables the firewall. SSH is allowed globally; NFS ports are LAN-only.

resource "null_resource" "ufw" {
  depends_on = [null_resource.packages]

  triggers = {
    lan_subnet = local.nfs_client_subnet
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
      "sudo ufw allow from ${local.nfs_client_subnet} to any port 2049 comment 'NFS'",
      "sudo ufw allow from ${local.nfs_client_subnet} to any port 111 comment 'NFS rpcbind'",
      "sudo ufw allow from ${local.nfs_client_subnet} to any port 20048 comment 'NFS mountd'",
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
