# Get Default project for the cluster
data "rancher2_project" "default" {
  cluster_id = rancher2_cluster_v2.hetzner_k8s_rke2.cluster_v1_id
  name       = "Default"

  depends_on = [rancher2_cluster_v2.hetzner_k8s_rke2]
}

data "rancher2_cluster_v2" "mgmt_cluster_v2_config" {
  name            = var.rancher_mgmt_cluster_name
  fleet_namespace = var.rancher_mgmt_cluster_namespace
}

data "rancher2_cluster_v2" "current_cluster_v2_config" {
  name            = var.cluster_name
  fleet_namespace = var.fleet_namespace
}