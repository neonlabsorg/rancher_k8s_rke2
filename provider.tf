terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 8.3"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.57"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "~> 1.7"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.9"
    }
  }
}

provider "rancher2" {
  api_url   = var.admin_url
  token_key = var.admin_token
}

provider "hcloud" {
  token = var.hetzner_api_token
}


provider "kubernetes" {
  alias = "rancher_mgmt_cluster"

  host     = local.kube_host_mgmt_cluster
  token    = local.kube_token_mgmt_cluster
  insecure = true
}

# Get kubeconfig data from Rancher Management Cluster and new RKE2 cluster
locals {
  kubeconfig_data_mgmt_cluster = yamldecode(data.rancher2_cluster_v2.mgmt_cluster_v2_config.kube_config)
  kube_host_mgmt_cluster       = local.kubeconfig_data_mgmt_cluster.clusters[0].cluster.server
  # TODO: Get kube_ca from Rancher Management Cluster, not it is not available in the kubeconfig
  # kube_ca = local.kubeconfig_data_mgmt_cluster.clusters[0].cluster["certificate-authority-data"]  
  kube_token_mgmt_cluster = local.kubeconfig_data_mgmt_cluster.users[0].user.token

  # Get kubeconfig data from new RKE2 cluster
  kubeconfig_data_current_cluster = yamldecode(rancher2_cluster_v2.hetzner_k8s_rke2.kube_config)
  kube_host_current_cluster       = local.kubeconfig_data_current_cluster.clusters[0].cluster.server
  kube_token_current_cluster      = local.kubeconfig_data_current_cluster.users[0].user.token
}

### Because we use custom manifests, we have to put it directly to rancher mgmt cluster, so this provider connects to mgmt cluster
provider "kubectl" {
  alias             = "rancher_mgmt_cluster"
  host              = local.kube_host_mgmt_cluster
  token             = local.kube_token_mgmt_cluster
  insecure          = true
  load_config_file  = false
  apply_retry_count = 10
}

provider "github" {
  owner = var.github_repository_owner
  token = var.github_token
}


provider "flux" {
  kubernetes = {
    host     = local.kube_host_current_cluster
    token    = local.kube_token_current_cluster
    insecure = true
  }
  git = {
    url    = "ssh://git@github.com/${var.github_repository_owner}/${var.github_repository_name}.git"
    branch = var.github_repository_branch
    ssh = {
      username    = "git"
      private_key = try(tls_private_key.git-main[0].private_key_pem, "")
    }
  }
}
