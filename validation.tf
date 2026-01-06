# Firewall configuration validation (uses precondition for hard errors, not warnings)
# ┌──────────┬──────────────────────┬─────────────────────────┬─────────────────────────────┐
# │ Mode     │ custom_firewall_ids  │ firewall_whitelist_ipv4 │ rancher_mgmt_cluster_nodes  │
# ├──────────┼──────────────────────┼─────────────────────────┼─────────────────────────────┤
# │ default  │ [] (empty)           │ optional                │ required (len > 0)          │
# │ custom   │ required (len > 0)   │ [] (empty)              │ [] (empty)                  │
# │ none     │ [] (empty)           │ [] (empty)              │ [] (empty)                  │
# └──────────┴──────────────────────┴─────────────────────────┴─────────────────────────────┘
# This resource ensures invalid firewall configurations fail at plan time
resource "terraform_data" "firewall_validation" {
  lifecycle {
    # MODE: default
    # - uses built-in RKE2 firewall, needs rancher nodes IPs for SSH whitelist
    # - custom_firewall_ids must be empty (we create firewall automatically)
    precondition {
      condition = (
        var.firewall_mode == "default"
        ? length(var.custom_firewall_ids) == 0 && length(var.rancher_mgmt_cluster_nodes_ipv4) > 0
        : true
      )
      error_message = "firewall_mode='default': custom_firewall_ids must be [] or not provided, rancher_mgmt_cluster_nodes_ipv4 is required."
    }

    # MODE: custom
    # - bring your own firewall, must provide firewall IDs
    # - whitelist variables are ignored (configure in your custom firewall)
    precondition {
      condition = (
        var.firewall_mode == "custom"
        ? length(var.custom_firewall_ids) > 0 && length(var.firewall_whitelist_ipv4) == 0 && length(var.rancher_mgmt_cluster_nodes_ipv4) == 0
        : true
      )
      error_message = "firewall_mode='custom': custom_firewall_ids required, firewall_whitelist_ipv4 and rancher_mgmt_cluster_nodes_ipv4 must be [] or not provided."
    }

    # MODE: none
    # - no firewall at all, all firewall variables must be empty
    precondition {
      condition = (
        var.firewall_mode == "none"
        ? length(var.custom_firewall_ids) == 0 && length(var.firewall_whitelist_ipv4) == 0 && length(var.rancher_mgmt_cluster_nodes_ipv4) == 0
        : true
      )
      error_message = "firewall_mode='none': all firewall variables (custom_firewall_ids, firewall_whitelist_ipv4, rancher_mgmt_cluster_nodes_ipv4) must be [] or not provided."
    }
  }
}
