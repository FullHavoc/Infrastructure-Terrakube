terraform {
  required_providers {
    terrakube = {
      source  = "registry.terraform.io/terrakube-io/terrakube"
      version = "~> 0.22"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
  
  # Temporarily using local backend for initial setup
  # Will migrate to remote backend after first apply
  backend "local" {
  }

  # Backend configuration should be provided via:
  # 1. Environment variables (TF_CLI_CONFIG_FILE)
  # 2. -backend-config flags during init
  # 3. backend.tfvars file (gitignored)
  #
  # Example backend.tfvars:
  # hostname     = "api.terrakube.yourdomain.com"
  # organization = "YourOrgName"
  # workspace    = "workspace-manager"
}

provider "terrakube" {
  endpoint = var.terrakube_endpoint
  token    = var.terrakube_token
}

# Get organization reference
data "terrakube_organization" "this" {
  name = var.terrakube_organization
}

# VCS connection (GitHub App for posting plan status checks on PRs)
data "terrakube_vcs" "github" {
  name            = var.vcs_name
  organization_id = data.terrakube_organization.this.id
}

# Get Plan-only template
data "terrakube_organization_template" "plan_only" {
  name            = "Plan"
  organization_id = data.terrakube_organization.this.id
}

# Repository configuration
locals {
  repository  = var.infrastructure_repo
  branch      = var.infrastructure_branch
  iac_type    = var.iac_type
  iac_version = var.iac_version
}

# Dynamic workspace discovery
data "external" "workspaces" {
  program = ["bash", "${path.module}/scan-workspaces.sh"]
}

locals {
  workspaces = {
    for k, v in data.external.workspaces.result : k => jsondecode(v)
  }
}

# Create child workspaces dynamically
resource "terrakube_workspace_vcs" "this" {
  for_each = local.workspaces

  organization_id = data.terrakube_organization.this.id
  vcs_id          = data.terrakube_vcs.github.id
  template_id     = data.terrakube_organization_template.plan_only.id

  name               = "${var.workspace_prefix}-${each.key}"
  description        = each.value.description
  repository         = local.repository
  branch             = local.branch
  folder             = each.value.folder
  execution_mode     = "remote"
  iac_type           = local.iac_type
  iac_version        = local.iac_version
  allow_remote_apply = false
}

# --- Manager workspace webhook ---
# Note: Manager workspace must already exist in Terrakube
# Create it manually or via separate bootstrap process
data "terrakube_workspace" "manager" {
  name         = var.manager_workspace_name
  organization = var.terrakube_organization
}

# TEMPORARILY DISABLED: Webhook provider has issues
# TODO: Re-enable after fixing webhook provider or Terrakube upgrade
#
# resource "terrakube_workspace_webhook_v2" "manager" {
#   organization_id = data.terrakube_organization.this.id
#   workspace_id    = data.terrakube_workspace.manager.id
#   migrated_v2     = true
# }
# 
# resource "terrakube_workspace_webhook_event" "push_manager" {
#   webhook_id  = terrakube_workspace_webhook_v2.manager.id
#   event       = "PUSH"
#   branch      = var.webhook_branches
#   path        = ["^${var.workspace_management_path}/.*"]
#   template_id = data.terrakube_organization_template.plan_only.id
#   priority    = 10
# }
# 
# resource "terrakube_workspace_webhook_event" "pr_manager" {
#   webhook_id  = terrakube_workspace_webhook_v2.manager.id
#   event       = "PULL_REQUEST"
#   branch      = var.webhook_branches
#   path        = ["^${var.workspace_management_path}/.*"]
#   template_id = data.terrakube_organization_template.plan_only.id
#   priority    = 10
# }
# 
# # --- Child workspace webhooks ---
# resource "terrakube_workspace_webhook_v2" "child" {
#   for_each = local.workspaces
# 
#   organization_id = data.terrakube_organization.this.id
#   workspace_id    = terrakube_workspace_vcs.this[each.key].id
#   migrated_v2     = true
# }
# 
# resource "terrakube_workspace_webhook_event" "push_child" {
#   for_each = local.workspaces
# 
#   webhook_id  = terrakube_workspace_webhook_v2.child[each.key].id
#   event       = "PUSH"
#   branch      = var.webhook_branches
#   path        = ["^${each.value.folder}/.*"]
#   template_id = data.terrakube_organization_template.plan_only.id
#   priority    = 10
# }
# 
# resource "terrakube_workspace_webhook_event" "pr_child" {
#   for_each = local.workspaces
# 
#   webhook_id  = terrakube_workspace_webhook_v2.child[each.key].id
#   event       = "PULL_REQUEST"
#   branch      = var.webhook_branches
#   path        = ["^${each.value.folder}/.*"]
#   template_id = data.terrakube_organization_template.plan_only.id
#   priority    = 10
# }
