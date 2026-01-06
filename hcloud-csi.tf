# # Hetzner CSI (Container Storage Interface)
# # Integrates Kubernetes with Hetzner Cloud for persistent storage

# # Hetzner CSI https://artifacthub.io/packages/helm/hcloud/hcloud-csi
resource "rancher2_catalog_v2" "hetzner_repo" {
  count      = var.hcloud_csi_enabled ? 1 : 0
  cluster_id = rancher2_cluster_v2.hetzner_k8s_rke2.cluster_v1_id

  name = "hetzner-cloud-charts"
  url  = "https://charts.hetzner.cloud"
}

resource "rancher2_app_v2" "hetzner_csi" {
  count      = var.hcloud_csi_enabled ? 1 : 0
  cluster_id = rancher2_cluster_v2.hetzner_k8s_rke2.cluster_v1_id

  name          = "hcloud-csi"
  namespace     = "kube-system"
  repo_name     = rancher2_catalog_v2.hetzner_repo[0].name
  chart_name    = "hcloud-csi"
  chart_version = var.hcloud_csi_chart_version
  values        = <<-EOF
storageClasses:
  - name: hcloud-volumes
    defaultStorageClass: true
    reclaimPolicy: Delete
    extraParameters: {}
%{if var.hcloud_csi_xfs_storage_class_enabled~}
  - name: hcloud-volumes-xfs
    defaultStorageClass: false
    reclaimPolicy: Delete
    extraParameters:
      csi.storage.k8s.io/fstype: xfs
%{endif~}
EOF

  depends_on = [
    rancher2_catalog_v2.hetzner_repo[0]
  ]
}
