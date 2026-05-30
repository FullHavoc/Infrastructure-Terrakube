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
