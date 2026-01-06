# Autoscaler https://artifacthub.io/packages/helm/cluster-autoscaler/cluster-autoscaler
locals {
  any_autoscaler_enabled = anytrue([for p in var.cluster_configurations.node_pools_machine_config : p.autoscaler_enabled])
  install_autoscaler     = local.any_autoscaler_enabled && !var.use_self_managed_cluster_autoscaler
}

resource "rancher2_namespace" "autoscaler_namespace" {
  count      = local.install_autoscaler ? 1 : 0
  name       = var.kubernetes_autoscaler_namespace
  project_id = data.rancher2_project.default.id

  depends_on = [rancher2_cluster_v2.hetzner_k8s_rke2]
}


resource "rancher2_token" "autoscaler_token" {
  count = local.install_autoscaler ? 1 : 0
  # cluster_id  = rancher2_cluster_v2.hetzner_k8s_rke2.cluster_v1_id - not working
  description = "Token for cluster-autoscaler in ${var.cluster_name}"
  ttl         = 0 # max allowed expiration time
  renew       = true
  lifecycle {
    ignore_changes = [
      ttl
    ]
  }
}

resource "rancher2_secret_v2" "autoscaler_secret" {
  count      = local.install_autoscaler ? 1 : 0
  cluster_id = rancher2_cluster_v2.hetzner_k8s_rke2.cluster_v1_id

  name      = "cluster-autoscaler-cloud-config"
  namespace = rancher2_namespace.autoscaler_namespace[0].name
  data = {
    "cloud-config" = <<-EOT
url: ${var.admin_url}
token: ${rancher2_token.autoscaler_token[0].token}
clusterName: ${var.cluster_name}
clusterNamespace: ${var.fleet_namespace}
EOT
  }
}

resource "rancher2_catalog_v2" "autoscaler_chart" {
  count      = local.install_autoscaler ? 1 : 0
  cluster_id = rancher2_cluster_v2.hetzner_k8s_rke2.cluster_v1_id

  name = "autoscaler-chart"
  url  = "https://kubernetes.github.io/autoscaler"
}

resource "rancher2_app_v2" "autoscaler" {
  count      = local.install_autoscaler ? 1 : 0
  cluster_id = rancher2_cluster_v2.hetzner_k8s_rke2.cluster_v1_id

  name          = "cluster-autoscaler"
  namespace     = rancher2_namespace.autoscaler_namespace[0].name
  repo_name     = rancher2_catalog_v2.autoscaler_chart[0].name
  chart_name    = "cluster-autoscaler"
  chart_version = var.kubernetes_autoscaler_chart_version
  values        = <<-EOF
  cloudProvider: rancher
  autoDiscovery:
    clusterName: ${var.cluster_name}
  extraVolumeSecrets:
    cluster-autoscaler-cloud-config:
      mountPath: /config
      name: cluster-autoscaler-cloud-config
  extraArgs:
    logtostderr: true
    stderrthreshold: info
    v: 4
    cloud-config: /config/cloud-config
    skip-nodes-with-system-pods: false
    skip-nodes-with-local-storage: false
  EOF

  depends_on = [
    rancher2_catalog_v2.autoscaler_chart,
    rancher2_secret_v2.autoscaler_secret
  ]
}


