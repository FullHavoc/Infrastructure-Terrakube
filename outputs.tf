output "vcs" {
  description = "VCS connection details"
  value = {
    id     = data.terrakube_vcs.github.id
    name   = data.terrakube_vcs.github.name
    status = data.terrakube_vcs.github.status
  }
}

output "workspaces" {
  description = "Created child workspaces"
  value = {
    for k, ws in terrakube_workspace_vcs.this : k => {
      id   = ws.id
      name = ws.name
    }
  }
}

output "manager_webhook_url" {
  description = "Terrakube webhook URL for the manager workspace — set this as the GitHub webhook payload URL"
  value       = "${var.terrakube_endpoint}/webhook/v1/${terrakube_workspace_webhook_v2.manager.id}"
}
