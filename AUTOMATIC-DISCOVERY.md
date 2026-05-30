# Automatic Workspace Discovery

## How It Works

Infrastructure-Terrakube uses **automatic workspace discovery** based on the presence of Terraform configurations. This is inspired by the pscloudops/terraform-infrastructure/v4 pattern.

### The Magic Formula

```
Directory + main.tf = Automatic Workspace ✨
```

**That's it!** No manual workspace configuration needed.

## Quick Start

### Create a New Workspace

```bash
# 1. Create directory
mkdir -p services/my-new-service

# 2. Add Terraform configuration
cat > services/my-new-service/main.tf <<EOF
resource "kubernetes_deployment" "app" {
  # Your configuration
}
EOF

# 3. Commit and push
git add services/my-new-service/
git commit -m "Add my-new-service"
git push

# 4. Terraform apply (in workspace management)
terraform apply
```

**Result**: Workspace `home-infrastructure-services-my-new-service` automatically created in Terrakube!

### Delete a Workspace

```bash
# 1. Remove the Terraform config
rm services/my-new-service/main.tf

# 2. Commit and push
git add services/my-new-service/
git commit -m "Remove my-new-service"
git push

# 3. Terraform apply
terraform apply
```

**Result**: Workspace automatically destroyed in Terrakube!

## How It Works Under the Hood

### The Scanner: `scan-workspaces.sh`

This script automatically discovers workspaces by:

1. **Scanning category directories**: `cluster/`, `services/`, `servers/`, `clients/`
2. **Looking for marker file**: `main.tf` (configurable)
3. **Creating workspace config**: Only for directories with Terraform code
4. **Outputting JSON**: For Terraform to consume

### Workspace Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│  You create: services/monitoring/main.tf                    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  scan-workspaces.sh detects main.tf                         │
│  Outputs: {"services-monitoring": {...}}                    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Terraform applies (main.tf reads scanner output)           │
│  Creates: terrakube_workspace_vcs.this["services-monitor"]  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Terrakube creates workspace:                               │
│  Name: home-infrastructure-services-monitoring              │
│  Folder: services/monitoring                                │
│  Repository: github.com/FullHavoc/Infrastructure-Terrakube  │
└─────────────────────────────────────────────────────────────┘
```

### What About Empty Directories?

**Empty directories are ignored!**

```bash
# This creates a directory but NO workspace
mkdir services/work-in-progress
# ← No main.tf yet, so no workspace created

# Add configuration when ready
echo "resource ..." > services/work-in-progress/main.tf
# ← Now workspace will be created on next apply
```

## Directory Structure

```
Infrastructure-Terrakube/
├── scan-workspaces.sh          # Workspace discovery script
├── main.tf                     # Reads scanner output, creates workspaces
│
├── cluster/                    # Cluster infrastructure workspaces
│   ├── argocd/
│   │   ├── main.tf            # ← Presence creates workspace
│   │   ├── variables.tf
│   │   └── .description       # Optional: custom description
│   └── hetzner/
│       └── main.tf            # ← Presence creates workspace
│
├── services/                   # Application service workspaces
│   ├── monitoring/
│   │   ├── main.tf            # ← Presence creates workspace
│   │   ├── variables.tf
│   │   └── terraform.tfvars.example
│   ├── awx/
│   │   └── main.tf            # ← Presence creates workspace
│   └── work-in-progress/      # ← NO main.tf = NO workspace
│
├── servers/                    # Infrastructure server workspaces
│   └── opnsense/
│       └── main.tf            # ← Presence creates workspace
│
└── clients/                    # Client device workspaces (optional)
    └── macmini/
        └── main.tf            # ← Presence creates workspace
```

## Customizing Discovery

### Change the Marker File

By default, `scan-workspaces.sh` looks for `main.tf`. You can change this:

```bash
# Look for workspace.tf instead
./scan-workspaces.sh workspace.tf

# Or any other file
./scan-workspaces.sh .terraform-workspace
```

Then update `main.tf`:

```hcl
data "external" "workspaces" {
  program = ["bash", "${path.module}/scan-workspaces.sh", "workspace.tf"]
}
```

### Custom Descriptions

Add a `.description` file in any workspace directory:

```bash
cat > services/monitoring/.description <<EOF
Prometheus and Grafana monitoring stack with alerting
EOF
```

This description appears in Terrakube UI.

### Scanning Specific Categories

Modify `scan-workspaces.sh` to scan different directories:

```bash
# In scan-workspaces.sh, change:
CATEGORIES=("cluster" "services" "servers" "clients")

# To:
CATEGORIES=("cluster" "services" "servers" "clients" "networking" "security")
```

## Comparison with Manual Workspace Management

### ❌ Old Way (Manual)

```hcl
# main.tf - hardcoded workspace list
resource "terrakube_workspace_vcs" "monitoring" {
  name   = "monitoring"
  folder = "services/monitoring"
  # ... configuration ...
}

resource "terrakube_workspace_vcs" "awx" {
  name   = "awx"
  folder = "services/awx"
  # ... configuration ...
}

# Adding new workspace requires:
# 1. Create directory
# 2. Add Terraform config to directory
# 3. Update main.tf with new workspace resource
# 4. Terraform apply
```

### ✅ New Way (Automatic)

```hcl
# main.tf - dynamic discovery
data "external" "workspaces" {
  program = ["bash", "${path.module}/scan-workspaces.sh"]
}

resource "terrakube_workspace_vcs" "this" {
  for_each = local.workspaces  # Automatically discovered
  # ... configuration ...
}

# Adding new workspace requires:
# 1. Create directory
# 2. Add Terraform config (main.tf)
# 3. Terraform apply
# ← No manual workspace definition needed!
```

## Example Workflow

### Scenario: Add SMTP Relay Service

**Step 1**: Create directory and configuration

```bash
mkdir -p services/smtp
cd services/smtp

cat > main.tf <<'EOF'
resource "kubernetes_deployment" "smtp_relay" {
  metadata {
    name      = var.deployment_name
    namespace = var.namespace
  }

  spec {
    replicas = var.replicas

    template {
      spec {
        container {
          name  = "postfix"
          image = var.smtp_image

          env {
            name  = "RELAY_HOST"
            value = var.relay_host
          }
        }
      }
    }
  }
}
EOF

cat > variables.tf <<'EOF'
variable "deployment_name" {
  default = "smtp-relay"
}

variable "namespace" {
  default = "smtp"
}

variable "replicas" {
  type    = number
  default = 2
}

variable "smtp_image" {
  default = "boky/postfix:latest"
}

variable "relay_host" {
  type        = string
  description = "External SMTP relay host"
  sensitive   = true
}
EOF

cat > terraform.tfvars.example <<'EOF'
deployment_name = "smtp-relay"
namespace       = "smtp"
replicas        = 2
smtp_image      = "boky/postfix:v3.6.0"

# SENSITIVE: Set via Terrakube Variables or local terraform.tfvars
# relay_host = "smtp.gmail.com:587"
EOF

echo "SMTP relay service for notifications" > .description
```

**Step 2**: Test discovery locally

```bash
cd ../..  # Back to repo root
./scan-workspaces.sh | jq .
# Should show services-smtp in output
```

**Step 3**: Commit and push

```bash
git add services/smtp/
git commit -m "Add SMTP relay service workspace"
git push
```

**Step 4**: Create workspace in Terrakube

```bash
# In workspace management directory
terraform plan
# Should show: + terrakube_workspace_vcs.this["services-smtp"]

terraform apply
# Workspace created automatically!
```

**Step 5**: Configure sensitive values

In Terrakube UI:

1. Go to workspace `home-infrastructure-services-smtp`
2. Settings → Variables
3. Add: `relay_host = "smtp.gmail.com:587"` (sensitive ✓)

**Step 6**: Run the workspace

Terrakube will now run plans/applies for `services/smtp` automatically via webhooks!

## Benefits

### 🎯 Zero-Touch Workspace Management

- No manual workspace definitions
- No hardcoded workspace lists
- No configuration drift

### 🚀 GitOps-Native

- Infrastructure as Code = Workspace
- Delete code = Delete workspace
- Perfect GitOps alignment

### 🧹 Self-Cleaning

- Empty directories don't create workspaces
- Removing `main.tf` triggers workspace destruction
- No orphaned workspaces

### 📊 Scalable

- Add 100 workspaces = Add 100 directories
- No main.tf updates needed
- Linear complexity

### 🔍 Discoverable

- `ls services/` shows all active services
- Presence of `main.tf` = active workspace
- Self-documenting structure

## Troubleshooting

### Workspace Not Created

**Problem**: Created `main.tf` but no workspace appears

**Solutions**:

1. Check scanner output:

   ```bash
   ./scan-workspaces.sh | jq .
   # Should show your workspace
   ```

2. Verify `main.tf` exists in correct location:

   ```bash
   ls -la services/your-service/main.tf
   ```

3. Run `terraform apply` in workspace management:
   ```bash
   terraform plan  # Should show workspace creation
   terraform apply
   ```

### Workspace Not Destroyed

**Problem**: Deleted `main.tf` but workspace still exists

**Solutions**:

1. Verify `main.tf` is actually deleted:

   ```bash
   ls services/your-service/main.tf
   # Should show: No such file or directory
   ```

2. Run `terraform apply`:
   ```bash
   terraform plan  # Should show workspace destruction
   terraform apply
   ```

### Scanner Returns Empty

**Problem**: `scan-workspaces.sh` returns `{}`

**Solutions**:

1. Check Python 3 is installed:

   ```bash
   python3 --version
   ```

2. Check directory structure:

   ```bash
   ls -la cluster/ services/ servers/ clients/
   ```

3. Check for `main.tf` files:
   ```bash
   find . -name "main.tf"
   ```

## Advanced Usage

### Custom Marker Files

Use different marker files for different purposes:

```bash
# Development workspaces (use dev.tf)
./scan-workspaces.sh dev.tf

# Production workspaces (use prod.tf)
./scan-workspaces.sh prod.tf

# Feature flags (use .enabled)
./scan-workspaces.sh .enabled
```

### Multi-Environment Pattern

```
services/
├── monitoring-dev/
│   └── main.tf       # Dev workspace
└── monitoring-prod/
    └── main.tf       # Prod workspace
```

Both get discovered automatically!

### Workspace Templates

Create template directories:

```bash
# Template (no main.tf)
mkdir -p .templates/service
cp .templates/service/* services/new-service/
# Still no workspace (no main.tf yet)

# When ready
mv services/new-service/main.tf.template services/new-service/main.tf
# NOW workspace is created!
```

## See Also

- [PSCloudOps Terraform Infrastructure](https://github.com/pscloudops/terraform-infrastructure) - Inspiration for this pattern
- [Terraform External Data Source](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) - How the scanner integrates
- [Terrakube Workspaces](https://docs.terrakube.io/) - Workspace management docs
