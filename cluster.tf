locals {
  node_pools_machine_config = { for cfg in var.cluster_configurations.node_pools_machine_config : cfg.name => cfg }
  # Dirty hack to ignore changes in machine_pools quantity in autoscaled machine_pools
  existing_machine_pools          = try(data.rancher2_cluster_v2.current_cluster_v2_config.rke_config[0].machine_pools, [])
  existing_machine_pools_quantity = { for pool in local.existing_machine_pools : pool.name => pool.quantity }

  # Firewall IDs for all cluster nodes (based on firewall_mode)
  firewall_ids = (
    var.firewall_mode == "default" ? [hcloud_firewall.rke2_calico_fw[0].id] :
    var.firewall_mode == "custom" ? var.custom_firewall_ids :
    [] # "none" mode
  )
}

# Create a unique hash for hetzner_machine_config to avoid conflicts with another clusters
resource "random_string" "unique_hash" {
  length  = 6
  special = false
  upper   = false
}

resource "kubectl_manifest" "hetzner_machine_config" {
  for_each  = local.node_pools_machine_config
  provider  = kubectl.rancher_mgmt_cluster
  yaml_body = <<YAML
apiVersion: rke-machine-config.cattle.io/v1
kind: HetznerConfig
metadata:
  name: ${var.cluster_name}-${each.value.name}-hetzner-machine-config-${random_string.unique_hash.result}
  namespace: ${var.fleet_namespace}
apiToken: "${var.hetzner_api_token}"
serverLocation: ${each.value.server_location}
serverType: ${each.value.server_type}
image: ${each.value.image}
imageArch: ""
imageId: ""
sshUser: root
sshPort: "22"
usePrivateNetwork: ${each.value.use_private_network}
firewalls: ${jsonencode(local.firewall_ids)}
userData: ""
userDataFile: ""
userDataFromFile: true
autoSpread: false
disablePublic: false
disablePublic4: false
disablePublic6: false
disablePublicIpv4: false
disablePublicIpv6: false
additionalKey: []
additionalUserData: |-
  ${each.value.use_default_cloud_init ? indent(4, file("${path.module}/cloud-init/default-cloud-init.yaml")) : indent(4, each.value.custom_cloud_init)}
existingKeyId: "0"
existingKeyPath: ""
keyLabel: []
networks: []
placementGroup: ""
primaryIpv4: ""
primaryIpv6: ""
serverLabel: []
volumes: []
waitForRunningTimeout: "0"
waitOnError: "0"
waitOnPolling: "1"
YAML

  sensitive_fields = [
    "apiToken"
  ]

  depends_on = [random_string.unique_hash]
}


resource "rancher2_cluster_v2" "hetzner_k8s_rke2" {
  name                  = var.cluster_name
  kubernetes_version    = var.cluster_configurations.kubernetes_version
  enable_network_policy = var.cluster_configurations.enable_network_policy
  fleet_namespace       = var.fleet_namespace

  rke_config {
    dynamic "machine_pools" {
      for_each = local.node_pools_machine_config
      content {
        name = machine_pools.value.name
        quantity = (
          # Dirty hack to ignore changes in machine_pools quantity in autoscaled machine_pools
          machine_pools.value.autoscaler_enabled
          # If autoscaler enabled, check current quantity in existing data
          ? lookup(
            # Choose quantity from existing machine pools quantity
            local.existing_machine_pools_quantity,
            machine_pools.value.name,
            # If not found, use quantity from variable
            machine_pools.value.quantity
          )
          # If autoscaler disabled, use quantity from variable
          : machine_pools.value.quantity
        )
        drain_before_delete = machine_pools.value.drain_before_delete
        machine_os          = machine_pools.value.machine_os
        paused              = machine_pools.value.paused
        # Role
        control_plane_role = machine_pools.value.control_plane
        etcd_role          = machine_pools.value.etcd
        worker_role        = machine_pools.value.worker
        # node labels/taints
        machine_labels = machine_pools.value.labels
        dynamic "taints" {
          for_each = machine_pools.value.node_taints != null ? machine_pools.value.node_taints : []
          content {
            key    = taints.value.key
            value  = taints.value.value
            effect = taints.value.effect
          }
        }

        machine_config {
          kind = kubectl_manifest.hetzner_machine_config[machine_pools.value.name].kind
          # Connect hetzner_machine_config to the machine_pool by name
          name = kubectl_manifest.hetzner_machine_config[machine_pools.value.name].name
        }

        # Autoscaler annotations (only when autoscaler_enabled = true)
        annotations = machine_pools.value.autoscaler_enabled ? {
          "cluster.provisioning.cattle.io/autoscaler-min-size" = machine_pools.value.autoscaler_min_size
          "cluster.provisioning.cattle.io/autoscaler-max-size" = machine_pools.value.autoscaler_max_size
        } : {}
      }
    }

    machine_global_config = yamlencode({
      cni                        = "calico"
      disable-kube-proxy         = false
      disable-cloud-controller   = true # Required for external CCM (Hetzner CCM)
      disable-kube-cloud-cleanup = true
      disable = [
        "rke2-ingress-nginx"
      ]
      etcd-expose-metrics = false
      kubelet-arg = [
        "cloud-provider=external",
        "container-log-max-size=${var.max_container_log_size}",
        "container-log-max-files=${var.max_container_log_files}"
      ]
    })

    additional_manifest = <<-EOF
---
# 1. Secret for Hetzner API used by Hetzner Cloud Controller Manager and other hetzner addons like Hetzner CSI
apiVersion: v1
kind: Secret
metadata:
  name: hcloud
  namespace: kube-system
stringData:
  token: "${var.hetzner_api_token}"
  network: "${var.management_network_id}"
  robot-user: "${var.robot_user}"
  robot-password: "${var.robot_password}"
---
# 2. HelmChart for HCLOUD CCM (Hetzner Cloud Controller Manager)
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: hcloud-cloud-controller-manager
  namespace: kube-system
spec:
  repo: https://charts.hetzner.cloud
  chart: hcloud-cloud-controller-manager
  version: ${var.hcloud_ccm_chart_version}
  targetNamespace: kube-system
  bootstrap: true 
  valuesContent: |-
    networking:
      enabled: true
      clusterCIDR: 10.42.0.0/16  # Default cluster CIDR for rke2-calico
    robot:
      enabled: ${var.enable_robot_support}
    additionalTolerations:
      - key: "node-role.kubernetes.io/etcd"
        operator: "Exists"
        effect: "NoExecute"
EOF

  }

  depends_on = [kubectl_manifest.hetzner_machine_config]
}