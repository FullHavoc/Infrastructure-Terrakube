variable "terrakube_endpoint" {
  type        = string
  description = "Terrakube API endpoint (e.g., https://api.terrakube.yourdomain.com)"
}

variable "terrakube_token" {
  type        = string
  description = "Terrakube API token with manageWorkspace permission"
  sensitive   = true
}

variable "terrakube_organization" {
  type        = string
  description = "Terrakube organization name"
}

variable "vcs_name" {
  type        = string
  description = "VCS connection name in Terrakube (e.g., 'MyOrg - GitHub')"
}

variable "vcs_connection_type" {
  type        = string
  description = "VCS connection type (OAUTH or STANDALONE)"
  default     = "OAUTH"

  validation {
    condition     = contains(["OAUTH", "STANDALONE"], var.vcs_connection_type)
    error_message = "vcs_connection_type must be either 'OAUTH' or 'STANDALONE'"
  }
}

variable "vcs_client_id" {
  type        = string
  description = "GitHub App client ID (for STANDALONE VCS)"
  default     = ""
}

variable "vcs_private_key_path" {
  type        = string
  description = "Path to the GitHub App private key file (for STANDALONE VCS)"
  default     = ""
}

variable "infrastructure_repo" {
  type        = string
  description = "Git repository URL containing actual infrastructure configurations"
}

variable "infrastructure_branch" {
  type        = string
  description = "Git branch to use for infrastructure configurations"
  default     = "main"
}

variable "workspace_prefix" {
  type        = string
  description = "Prefix for workspace names (e.g., 'infra' creates 'infra-services-monitoring')"
  default     = "infra"
}

variable "manager_workspace_name" {
  type        = string
  description = "Name of the manager workspace that runs this configuration"
  default     = "workspace-manager"
}

variable "iac_type" {
  type        = string
  description = "IaC tool type (terraform or tofu)"
  default     = "terraform"

  validation {
    condition     = contains(["terraform", "tofu"], var.iac_type)
    error_message = "iac_type must be either 'terraform' or 'tofu'"
  }
}

variable "iac_version" {
  type        = string
  description = "Terraform/OpenTofu version to use in workspaces"
  default     = "1.15.5"
}

variable "webhook_branches" {
  type        = list(string)
  description = "Branch patterns for webhook filtering (glob — Terrakube uses glob matching)"
  default     = ["*"]
}
