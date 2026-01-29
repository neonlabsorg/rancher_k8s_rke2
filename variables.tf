# Required
variable "cluster_name" {
  type        = string
  description = "Rancher Cluster Name"
}

# Required
variable "hetzner_api_token" {
  type        = string
  description = "Hetzner Cloud API Token"
  sensitive   = true
}

# Optional
variable "rancher_mgmt_cluster_name" {
  type        = string
  description = "Rancher Management Cluster Name"
  default     = "local"
}

# Optional
variable "rancher_mgmt_cluster_namespace" {
  type        = string
  description = "Rancher Management Cluster Namespace"
  default     = "fleet-local"
}

variable "fleet_namespace" {
  type = string
  # Namespace for the cluster resources in managed rancher cluster
  # https://registry.terraform.io/providers/rancher/rancher2/latest/docs/resources/cluster_v2#fleet_namespace-1
  description = "Fleet Namespace"
  default     = "fleet-default"
}

# Required
variable "cluster_configurations" {
  description = "value for the cluster configurations"
  type = object({
    description           = string
    kubernetes_version    = string
    enable_network_policy = optional(bool, false)
    node_pools_machine_config = list(object({
      name                   = string
      server_type            = string
      server_location        = string
      image                  = string
      quantity               = number
      control_plane          = bool
      etcd                   = bool
      worker                 = bool
      autoscaler_enabled     = optional(bool, false)
      autoscaler_min_size    = optional(number, 1)
      autoscaler_max_size    = optional(number, 3)
      drain_before_delete    = optional(bool, true)
      machine_os             = optional(string, "linux")
      paused                 = optional(bool, false)
      use_private_network    = optional(bool, true)
      use_default_cloud_init = optional(bool, true)
      custom_cloud_init      = optional(string, "")
      labels                 = optional(map(string))
      node_taints = optional(list(object({
        key    = string
        value  = string
        effect = string
      })))
    }))
  })
  validation {
    # Ensures all node pool names are unique.
    condition = length(
    distinct([for p in var.cluster_configurations.node_pools_machine_config : p.name])) == length(var.cluster_configurations.node_pools_machine_config)
    error_message = "The 'name' fields in 'node_pools_machine_config' must be unique. Duplicate node pool names were detected."
  }
  validation {
    # Ensures all node pool names comply with the Kubernetes RFC 1123 Subdomain naming convention.
    condition = alltrue([
      for p in var.cluster_configurations.node_pools_machine_config :
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", p.name))
    ])
    error_message = <<-EOT
    Invalid 'node_pools_machine_config' names: ${jsonencode([for p in var.cluster_configurations.node_pools_machine_config : p.name if !can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", p.name))])}.
    Names must be lowercase alphanumeric, may include '-', and start/end with alphanumeric (RFC 1123).
    EOT
  }
  validation {
    # Ensures use_default_cloud_init and custom_cloud_init are mutually exclusive.
    condition = alltrue([
      for p in var.cluster_configurations.node_pools_machine_config :
      !(p.use_default_cloud_init && p.custom_cloud_init != "")
    ])
    error_message = <<-EOT
    Invalid cloud-init configuration for node pools: ${jsonencode([for p in var.cluster_configurations.node_pools_machine_config : p.name if p.use_default_cloud_init && p.custom_cloud_init != ""])}.
    Cannot use both 'use_default_cloud_init = true' and 'custom_cloud_init' at the same time. Set 'use_default_cloud_init = false' to use custom cloud-init.
    EOT
  }
  validation {
    # Ensures autoscaler_min_size is >= 1.
    condition = alltrue([
      for p in var.cluster_configurations.node_pools_machine_config :
      p.autoscaler_min_size >= 1
    ])
    error_message = <<-EOT
    Invalid autoscaler_min_size for node pools: ${jsonencode([for p in var.cluster_configurations.node_pools_machine_config : p.name if p.autoscaler_min_size < 1])}.
    autoscaler_min_size must be >= 1.
    EOT
  }
  validation {
    # Ensures autoscaler_max_size is >= autoscaler_min_size.
    condition = alltrue([
      for p in var.cluster_configurations.node_pools_machine_config :
      p.autoscaler_max_size >= p.autoscaler_min_size
    ])
    error_message = <<-EOT
    Invalid autoscaler configuration for node pools: ${jsonencode([for p in var.cluster_configurations.node_pools_machine_config : p.name if p.autoscaler_max_size < p.autoscaler_min_size])}.
    autoscaler_max_size must be >= autoscaler_min_size.
    EOT
  }
}

variable "rke2_network_range" {
  type        = string
  default     = "10.0.0.0/16"
  description = "RKE2 Network Range"
  validation {
    condition     = can(cidrnetmask(var.rke2_network_range))
    error_message = "rke2_network_range must be a valid IPv4 CIDR."
  }
}

variable "rke2_subnet_network_range" {
  type        = string
  default     = "10.0.0.0/23"
  description = "RKE2 Subnet Network Range"
  validation {
    condition     = can(cidrnetmask(var.rke2_subnet_network_range))
    error_message = "rke2_subnet_network_range must be a valid IPv4 CIDR."
  }
}

variable "rke2_subnet_network_zone" {
  type        = string
  default     = "eu-central"
  description = <<-EOT
    RKE2 Subnet Network Zone. Hetzner Cloud supported zones: eu-central, us-east, us-west, ap-southeast
    Robot supported only in eu-central zone.
  EOT
  validation {
    condition     = contains(["eu-central", "us-east", "us-west", "ap-southeast"], var.rke2_subnet_network_zone)
    error_message = "rke2_subnet_network_zone must be one of: eu-central, us-east, us-west, ap-southeast."
  }
}

variable "hcloud_ccm_chart_version" {
  type        = string
  default     = "1.29.2" # last available version when this module was created
  description = <<-EOT
    Hetzner Cloud Controller Manager Chart Version
    Docs link: https://artifacthub.io/packages/helm/hcloud/hcloud-cloud-controller-manager
  EOT
}

variable "hcloud_csi_enabled" {
  type        = bool
  default     = true
  description = "Enable Hetzner CSI"
}

variable "hcloud_csi_chart_version" {
  type        = string
  default     = "2.18.3" # last available version when this module was created
  description = <<-EOT
    Hetzner CSI Chart Version
    Docs link: https://artifacthub.io/packages/helm/hcloud/hcloud-csi
  EOT
}

variable "hcloud_csi_xfs_storage_class_enabled" {
  type        = bool
  default     = true
  description = "Create additional StorageClass with XFS filesystem (hcloud-volumes-xfs)"
}

variable "use_self_managed_cluster_autoscaler" {
  type        = bool
  description = <<-EOT
    Use self managed cluster autoscaler instead of helm chart provided by this module.
    ATTENTION: You still have use autoscaler_enabled=true, autoscaler_min_size and autoscaler_max_size variables to configure the autoscaler.
    Docs link: https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/rancher
  EOT
  default     = false
}

variable "kubernetes_autoscaler_chart_version" {
  type        = string
  default     = "9.53.0" # last available version when this module was created
  description = "Kubernetes Autoscaler Chart Version"
}

variable "kubernetes_autoscaler_namespace" {
  type        = string
  default     = "autoscaler"
  description = "Kubernetes Autoscaler Namespace"
}

# Required
variable "admin_url" {
  type        = string
  description = "Rancher Admin URL"
}

# Required
variable "admin_token" {
  type        = string
  description = "Rancher Admin Token"
}

variable "max_container_log_size" {
  type        = string
  default     = "200Mi"
  description = "Maximum size of the container log"
}

variable "max_container_log_files" {
  type        = string
  default     = "2"
  description = "Maximum number of the container log files"
}

# # Required

variable "flux_enabled" {
  type        = bool
  default     = true
  description = "Enable Flux"
}


variable "github_token" {
  type        = string
  description = "Flux repository github token"
  sensitive   = true
}

variable "github_repository_owner" {
  type        = string
  default     = "neonlabsorg"
  description = "Flux repository github owner"
}

variable "github_repository_name" {
  type        = string
  default     = "flux-infra"
  description = "Flux repository name"
}

variable "github_repository_branch" {
  type        = string
  default     = "main"
  description = "Default branch to sync from"
}

variable "flux_namespace" {
  type        = string
  default     = "flux-system"
  description = "The namespace scope for this operation"
}

variable "flux_repo_target_path" {
  type        = string
  default     = null
  description = "Relative path to the Git repository root where Flux manifests are committed"
}

variable "flux_components" {
  type        = list(string)
  default     = ["source-controller", "kustomize-controller", "helm-controller", "notification-controller"]
  description = "Toolkit components to include in the install manifests"
}

variable "flux_components_extra" {
  type        = list(string)
  default     = ["image-reflector-controller", "image-automation-controller"]
  description = "List of extra components to include in the install manifests"
}

variable "flux_version" {
  type        = string
  default     = "latest"
  description = "Flux version"
}

variable "flux_registry" {
  type        = string
  default     = "ghcr.io/fluxcd"
  description = "Container registry where the toolkit images are published"
}

variable "flux_image_pull_secret" {
  type        = string
  default     = null
  description = "Kubernetes secret name used for pulling the toolkit images from a private registry"
}

# --- Firewall Configuration ---
# ref: https://docs.rke2.io/install/requirements#inbound-network-rules

variable "firewall_mode" {
  type        = string
  default     = "default"
  description = <<-EOT
    Firewall mode for all cluster nodes:
    - "default" = use built-in RKE2 firewall rules (hcloud_firewall created by this module)
    - "custom"  = use custom_firewall_ids (bring your own firewall)
    - "none"    = no firewall attached to nodes
  EOT
  validation {
    condition     = contains(["default", "custom", "none"], var.firewall_mode)
    error_message = "firewall_mode must be 'default', 'custom', or 'none'"
  }
}

variable "custom_firewall_ids" {
  type        = list(number)
  default     = []
  description = "List of Hetzner Cloud firewall IDs to attach to all cluster nodes (only used when firewall_mode = 'custom')"
}

variable "firewall_whitelist_ipv4" {
  type        = list(string)
  default     = []
  description = "List of IPv4 addresses/CIDRs to whitelist for SSH access to cluster nodes (only used when firewall_mode = 'default')"
}

# Required when firewall_mode = "default"
variable "rancher_mgmt_cluster_nodes_ipv4" {
  type        = list(string)
  default     = []
  description = "List of IPv4 addresses of the Rancher management cluster nodes (for SSH whitelist, required when firewall_mode = 'default')"
}

# Optional Robot support
variable "enable_robot_support" {
  type        = bool
  default     = false
  description = "Enable Hetzner Robot support in hcloud-cloud-controller-manager"
}

variable "robot_user" {
  type        = string
  default     = ""
  description = "Hetzner Robot username (required if enable_robot_support is true)"
  sensitive   = true
}

variable "robot_password" {
  type        = string
  default     = ""
  description = "Hetzner Robot password (required if enable_robot_support is true)"
  sensitive   = true
}

check "robot_support_inputs" {
  # Check if robot_user and robot_password are provided and non-empty if enable_robot_support is true
  assert {
    condition = var.enable_robot_support == false || (
      length(trimspace(var.robot_user)) > 0 && length(trimspace(var.robot_password)) > 0
    )
    error_message = "When enable_robot_support is true, both robot_user and robot_password must be provided and non-empty."
  }
}
