# Terrakube Workspaces

Dynamic workspace management for Terrakube using the `terrakube-io/terrakube` provider.

This repository contains the **workspace structure and management configuration** for a Terrakube-based GitOps workflow. The actual infrastructure configurations (`.tf` files) are stored in a separate private repository.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  terrakube-workspaces (PUBLIC)                              │
│  ├── Workspace structure (directories)                      │
│  ├── Workspace discovery automation (scan-workspaces.sh)    │
│  └── Workspace management (main.tf)                         │
└─────────────────────────────────────────────────────────────┘
                           ↓
                    Terrakube reads from
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  your-infrastructure-repo (PRIVATE)                         │
│  ├── cluster/argocd/main.tf       ← Actual configs          │
│  ├── services/monitoring/main.tf  ← Actual configs          │
│  └── servers/opnsense/main.tf     ← Actual configs          │
└─────────────────────────────────────────────────────────────┘
```

## ✨ Features

- **Dynamic Workspace Discovery**: Automatically creates/destroys Terrakube workspaces based on directory structure
- **GitOps Integration**: Webhooks for PR status checks and push-triggered plans
- **VCS Integration**: GitHub OAuth App integration (not PAT)
- **Plan-Only Child Workspaces**: All child workspaces run plans only (no auto-apply)
- **Path Filtering**: Each workspace only triggers on changes to its directory
- **Customizable Descriptions**: Use `.description` files to document each workspace

## 📁 Directory Structure

```
terrakube-workspaces/
├── README.md                    # This file
├── .gitignore                   # Ignore sensitive files
├── terraform.tfvars.example     # Example configuration
├── main.tf                      # Workspace management logic
├── variables.tf                 # Variable declarations
├── scan-workspaces.sh           # Dynamic workspace discovery
├── cluster/                     # Cluster-level infrastructure
│   ├── argocd/.description
│   └── hetzner/.description
├── services/                    # K8s services and applications
│   ├── awx/.description
│   ├── crowdsec/.description
│   ├── matrix/.description
│   └── monitoring/.description
├── servers/                     # Infrastructure servers
│   ├── opnsense/.description
│   ├── truenas/.description
│   └── homeassistant/.description
└── clients/                     # Client devices (if managed)
    ├── macmini/.description
    └── macbook/.description
```

## 🚀 Getting Started

### Prerequisites

1. **Terrakube instance** deployed and accessible
2. **GitHub OAuth App** configured for VCS integration
3. **Terrakube API token** with `manageWorkspace` permission
4. **Private infrastructure repository** containing actual Terraform configurations

### Configuration

1. **Clone this repository**:

   ```bash
   git clone https://github.com/FullHavoc/terrakube-workspaces.git
   cd terrakube-workspaces
   ```

2. **Copy example variables**:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars** with your values:

   ```hcl
   terrakube_endpoint      = "https://api.terrakube.yourdomain.com"
   terrakube_organization  = "YourOrgName"
   infrastructure_repo     = "https://github.com/your-org/your-infrastructure"
   infrastructure_branch   = "main"
   workspace_prefix        = "infra"
   vcs_name                = "YourOrgName - GitHub"
   terrakube_token         = "your-token-here"  # Or set via TF_VAR_terrakube_token
   ```

4. **Initialize Terraform**:

   ```bash
   terraform init
   ```

5. **Review the plan**:

   ```bash
   terraform plan
   ```

6. **Apply** (creates workspaces and webhooks):
   ```bash
   terraform apply
   ```

## 📝 Adding a New Workspace

1. **Create a directory** under the appropriate category:

   ```bash
   mkdir -p services/new-service
   ```

2. **(Optional) Add a description**:

   ```bash
   echo "Manages the new-service deployment" > services/new-service/.description
   ```

3. **Commit and push**:

   ```bash
   git add services/new-service/
   git commit -m "Add new-service workspace"
   git push
   ```

4. **Run Terraform** (in this workspace management repo):

   ```bash
   terraform apply
   # Creates workspace "infra-services-new-service" in Terrakube
   ```

5. **Add actual Terraform configs** in your **private infrastructure repo**:
   ```bash
   # In your-infrastructure-repo
   mkdir -p services/new-service
   cat > services/new-service/main.tf <<EOF
   # Your actual infrastructure code here
   EOF
   git add services/new-service/
   git commit -m "Add new-service infrastructure"
   git push
   # Triggers Terrakube plan via webhook
   ```

## 🔧 How It Works

### Dynamic Discovery

The `scan-workspaces.sh` script:

1. Scans `cluster/`, `services/`, `servers/`, `clients/` directories
2. Outputs JSON mapping workspace keys to folders
3. Terraform uses this to create/destroy workspaces dynamically

### Webhook Integration

Each workspace gets:

- **PUSH events**: Trigger plans on commits (filtered by path)
- **PULL_REQUEST events**: Post status checks on PRs (filtered by path)

Example: Changes to `services/monitoring/` only trigger the `monitoring` workspace.

### Workspace Naming

Format: `{workspace_prefix}-{category}-{name}`

Examples:

- `infra-cluster-hetzner`
- `infra-services-monitoring`
- `infra-servers-opnsense`

## 🔒 Security Best Practices

### What to Keep Private

- **Terraform configurations** (`.tf` files with actual infrastructure)
- **Variable values** (`terraform.tfvars`)
- **Terrakube tokens** (use environment variables: `TF_VAR_terrakube_token`)
- **State files** (use remote backend)

### What's Safe to Publish

- **Workspace structure** (directory layout)
- **Discovery scripts** (generic automation)
- **Management configuration** (this repo's `main.tf`)
- **Documentation** (usage guides, examples)

### Recommendations

1. **Never commit** `terraform.tfvars` or `*.auto.tfvars`
2. **Use environment variables** for sensitive values:
   ```bash
   export TF_VAR_terrakube_token="your-token"
   ```
3. **Enable branch protection** on this repo (free for public repos!)
4. **Review PRs carefully** before merging workspace changes

## 🛠️ Customization

### Changing Workspace Categories

Edit the `scan-workspaces.sh` script to scan different directories:

```bash
# Add new category
CATEGORIES=("cluster" "services" "servers" "clients" "networking")
```

### Custom Descriptions

Place a `.description` file in any workspace directory:

```bash
echo "Production Kubernetes cluster in Hetzner Cloud" > cluster/hetzner/.description
```

If no `.description` exists, a generic description is generated from the directory name.

### Terraform Version

Workspaces default to OpenTofu 1.15.5. Change in `variables.tf`:

```hcl
variable "iac_version" {
  default = "1.15.5"  # Or any version supported by Terrakube
}
```

## 📊 Example Workflow

### PR-Based Changes

1. **Create feature branch**:

   ```bash
   git checkout -b feature/add-smtp-service
   ```

2. **Add workspace directory**:

   ```bash
   mkdir -p services/smtp
   echo "SMTP relay service" > services/smtp/.description
   git add services/smtp/
   git commit -m "Add SMTP workspace"
   ```

3. **Push and create PR**:

   ```bash
   git push -u origin feature/add-smtp-service
   gh pr create --title "Add SMTP service workspace"
   ```

4. **Terrakube runs plan**, posts status check on PR

5. **Merge PR** after review

6. **Terraform apply** creates the workspace in Terrakube

7. **Add infrastructure code** in private repo, triggers Terrakube plan

## 🤝 Contributing

Contributions welcome! This repo is public to share Terrakube workspace management patterns with the community.

Please:

- Keep PRs focused on workspace structure/automation
- Don't commit actual infrastructure configurations
- Test changes locally before opening PRs
- Update documentation for new features

## 📄 License

MIT License - See LICENSE file for details

## 🔗 Related Projects

- [Terrakube](https://github.com/AzBuilder/terrakube) - Open-source Terraform automation platform
- [terrakube-io/terrakube](https://registry.terraform.io/providers/terrakube-io/terrakube/latest) - Terraform provider

## 💬 Support

- **Issues**: Open an issue for bugs or feature requests
- **Discussions**: Share your workspace patterns and use cases
- **Terrakube Docs**: https://docs.terrakube.io

---

**Note**: This repository contains only workspace structure and automation. Actual infrastructure configurations should be kept in a separate private repository for security.
