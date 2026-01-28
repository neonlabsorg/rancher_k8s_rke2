# RKE2 Cluster Firewall (only created when firewall_mode = "default")
resource "hcloud_firewall" "rke2_calico_fw" {
  count = var.firewall_mode == "default" ? 1 : 0
  name  = "${var.cluster_name}-rke2-firewall"

  # --- SSH Access (whitelisted IPs only) ---
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = concat(var.rancher_mgmt_cluster_nodes_ipv4, var.firewall_whitelist_ipv4)
    description = "SSH access (whitelisted IPs)"
  }
  # ============================================================================
  # RKE2 Port Requirements
  # ref: https://docs.rke2.io/install/requirements#inbound-network-rules
  # ref: https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements/port-requirements
  # ref: https://kubernetes.io/docs/reference/networking/ports-and-protocols/
  # ============================================================================

  # --- RKE2 Core Ports ---

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "9345"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "RKE2 supervisor API. Required for node registration (Master nodes only)"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Kubernetes API Server. Required for kubectl access"
  }

  # --- etcd Ports (server nodes only) ---
  # ref: https://docs.rke2.io/install/requirements#inbound-network-rules

  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "2379"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "etcd client port"
  # }
  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "2380"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "etcd peer port"
  # }
  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "2381"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "etcd metrics port (RKE2 specific)"
  # }

  # --- Kubelet & Kubernetes Components ---
  # ref: https://kubernetes.io/docs/reference/networking/ports-and-protocols/

  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "10250"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "Kubelet API (metrics, exec, logs)"
  # }

  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "10256"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "kube-proxy health check"
  # }
  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "10257"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "kube-controller-manager (server nodes only)"
  # }
  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "10259"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "kube-scheduler (server nodes only)"
  # }

  # --- CNI: Canal
  # ref: https://docs.rke2.io/install/requirements#cni-specific-inbound-network-rules
  # Canal = Flannel (networking) + Calico (network policy)

  # rule {
  #   direction   = "in"
  #   protocol    = "udp"
  #   port        = "8472"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "Canal/Flannel VXLAN overlay network"
  # }
  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "9099"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "Canal/Flannel health checks"
  # }

  # --- CNI: Calico (if using Calico instead of Canal) ---
  # ref: https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements

  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "179"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "Calico BGP (only if using Calico with BGP)"
  # }
  # rule {
  #   direction   = "in"
  #   protocol    = "udp"
  #   port        = "4789"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "Calico VXLAN (only if using Calico with VXLAN or Windows nodes)"
  # }
  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "5473"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "Calico Typha (only if using Calico with Typha)"
  # }


  # --- CNI: WireGuard encryption (optional) ---
  # ref: https://docs.rke2.io/install/requirements#cni-specific-inbound-network-rules
  # Required only if using Canal/Calico with WireGuard encryption enabled

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "51820"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "WireGuard IPv4 for Calico encryption"
  }

  # --- NodePort Services ---

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "30000-32767"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "NodePort service range (TCP)"
  }
  # rule {
  #   direction   = "in"
  #   protocol    = "udp"
  #   port        = "30000-32767"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "NodePort service range (UDP)"
  # }

  # --- Ingress Controller ---

  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "80"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "HTTP ingress traffic"
  # }
  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "443"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "HTTPS ingress traffic, Rancher UI/API, kubectl"
  # }
  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "10254"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "Ingress controller health checks (nginx-ingress)"
  # }


  # --- Monitoring (optional) ---
  # ref: https://ranchermanager.docs.rancher.com/integrations-in-rancher/monitoring-and-alerting/how-monitoring-works

  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "9100"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "Node Exporter metrics (Rancher Monitoring)"
  # }
  # rule {
  #   direction   = "in"
  #   protocol    = "tcp"
  #   port        = "10249"
  #   source_ips  = ["0.0.0.0/0", "::/0"]
  #   description = "kube-proxy metrics (Rancher Monitoring)"
  # }
}
