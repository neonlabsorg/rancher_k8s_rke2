resource "tls_private_key" "git-main" {
  count = var.flux_enabled ? 1 : 0

  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "github_repository_deploy_key" "main" {
  count = var.flux_enabled ? 1 : 0

  title      = "k8s-rke2-${var.cluster_name}"
  repository = var.github_repository_name
  key        = tls_private_key.git-main[0].public_key_openssh
  read_only  = false
}

resource "flux_bootstrap_git" "main" {
  count = var.flux_enabled ? 1 : 0

  embedded_manifests = true
  network_policy     = true
  components         = var.flux_components
  components_extra   = var.flux_components_extra
  namespace          = var.flux_namespace
  registry           = var.flux_registry
  version            = var.flux_version
  image_pull_secret  = var.flux_image_pull_secret
  path               = try(length(var.flux_repo_target_path), 0) > 0 ? var.flux_repo_target_path : "clusters/hcloud-${var.cluster_name}"

  depends_on = [github_repository_deploy_key.main[0], rancher2_cluster_v2.hetzner_k8s_rke2]
}
