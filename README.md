# Rancher RKE2 Kubernetes Cluster on Hetzner Cloud

Terraform module for deploying RKE2 Kubernetes clusters on Hetzner Cloud via Rancher.

## Features

- **RKE2 Cluster** — Provisions Kubernetes clusters using Rancher's RKE2 distribution
- **Hetzner Cloud Integration** — Native support for Hetzner Cloud Controller Manager (CCM) and CSI
- **Cluster Autoscaler** — Optional automatic node scaling via Rancher provider
- **Flux CD** — Optional GitOps with Flux bootstrap
- **Firewall Management** — Configurable firewall rules (default/custom/none)
- **Custom Cloud-Init** — Per-node-pool cloud-init configuration

## Usage

```hcl
module "k8s_cluster" {
  source = "./rancher_k8s_rke2"

  cluster_name      = "my-cluster"
  hetzner_api_token = var.hetzner_api_token
  admin_url         = "https://rancher.example.com"
  admin_token       = var.rancher_token
  github_token      = var.github_token

  rancher_mgmt_cluster_nodes_ipv4 = ["1.2.3.4", "5.6.7.8"]

  cluster_configurations = {
    description        = "Production Cluster"
    kubernetes_version = "v1.32.9+rke2r1"

    node_pools_machine_config = [
      {
        name            = "master"
        server_type     = "ccx13"
        server_location = "nbg1"
        image           = "ubuntu-24.04"
        quantity        = 3
        control_plane   = true
        etcd            = true
        worker          = false
      },
      {
        name               = "worker"
        server_type        = "ccx23"
        server_location    = "nbg1"
        image              = "ubuntu-24.04"
        quantity           = 2
        control_plane      = false
        etcd               = false
        worker             = true
        autoscaler_enabled = true
        autoscaler_min_size = 2
        autoscaler_max_size = 10
      }
    ]
  }
}
```

## Requirements

| Provider | Version |
|----------|---------|
| rancher2 | ~> 8.3 |
| hcloud | ~> 1.57 |
| kubectl | ~> 1.19 |
| flux | ~> 1.7 |
| github | ~> 6.9 |

## Required Variables

| Variable | Description |
|----------|-------------|
| `cluster_name` | Name of the RKE2 cluster |
| `hetzner_api_token` | Hetzner Cloud API token |
| `admin_url` | Rancher management server URL |
| `admin_token` | Rancher API token |
| `github_token` | GitHub token for Flux (if `flux_enabled = true`) |
| `cluster_configurations` | Cluster and node pool configuration object |

## Firewall Modes

| Mode | Description |
|------|-------------|
| `default` | Creates RKE2-specific firewall with SSH whitelist (requires `rancher_mgmt_cluster_nodes_ipv4`) |
| `custom` | Attach your own firewall IDs via `custom_firewall_ids` |
| `none` | No firewall attached to nodes |

## Node Pool Configuration

Each node pool in `cluster_configurations.node_pools_machine_config` supports:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | required | Unique pool name (RFC 1123) |
| `server_type` | string | required | Hetzner server type (e.g., `ccx23`) |
| `server_location` | string | required | Hetzner datacenter (e.g., `nbg1`, `fsn1`) |
| `image` | string | required | OS image (e.g., `ubuntu-24.04`) |
| `quantity` | number | required | Number of nodes |
| `control_plane` | bool | required | Is control plane node |
| `etcd` | bool | required | Is etcd node |
| `worker` | bool | required | Is worker node |
| `autoscaler_enabled` | bool | `false` | Enable cluster autoscaler |
| `autoscaler_min_size` | number | `1` | Minimum nodes (when autoscaler enabled) |
| `autoscaler_max_size` | number | `3` | Maximum nodes (when autoscaler enabled) |
| `labels` | map(string) | `null` | Kubernetes node labels |
| `node_taints` | list(object) | `null` | Kubernetes node taints |
| `use_default_cloud_init` | bool | `true` | Use default cloud-init |
| `custom_cloud_init` | string | `""` | Custom cloud-init config |

## Components

### Hetzner Cloud Controller Manager (CCM)

Automatically deployed via HelmChart. Handles:
- Node lifecycle management
- Load balancer provisioning
- Network integration

### Hetzner CSI

Optional (`hcloud_csi_enabled = true`). Provides:
- `hcloud-volumes` — Default StorageClass (ext4)
- `hcloud-volumes-xfs` — Optional XFS StorageClass

### Cluster Autoscaler

Automatically deployed when any node pool has `autoscaler_enabled = true`. Uses Rancher cloud provider.

### Flux CD

Optional GitOps bootstrap (`flux_enabled = true`). Components:
- source-controller
- kustomize-controller
- helm-controller
- notification-controller
- image-reflector-controller (extra)
- image-automation-controller (extra)

## Files Structure

```
rancher_k8s_rke2/
├── provider.tf      # Provider configurations
├── variables.tf     # Input variables
├── cluster.tf       # RKE2 cluster + Hetzner machine configs
├── data.tf          # Data sources
├── firewall.tf      # Hetzner firewall rules
├── validation.tf    # Input validation
├── hcloud-csi.tf    # Hetzner CSI driver
├── autoscaler.tf    # Cluster autoscaler
├── flux.tf          # Flux CD bootstrap
└── cloud-init/
    └── default-cloud-init.yaml
```

## Notes

- The module uses Calico CNI by default
- RKE2 ingress-nginx is disabled (deploy your own ingress controller)
- Container log rotation is configured via `max_container_log_size` and `max_container_log_files`
- Robot support (`enable_robot_support`) enables Hetzner dedicated server integration in CCM
