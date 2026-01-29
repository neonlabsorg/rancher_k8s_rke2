resource "hcloud_network" "rke2_network" {
  name     = "${var.cluster_name}-network"
  ip_range = var.rke2_network_range
}

resource "hcloud_network_subnet" "rke2_subnet" {
  network_id   = hcloud_network.rke2_network.id
  type         = "cloud"
  network_zone = var.rke2_subnet_network_zone
  ip_range     = var.rke2_subnet_network_range

  lifecycle {
    precondition {
      condition = (
        can(cidrhost(var.rke2_network_range, 0)) &&
        can(cidrhost(var.rke2_subnet_network_range, 0)) &&
        tonumber(split("/", var.rke2_subnet_network_range)[1]) >= tonumber(split("/", var.rke2_network_range)[1]) &&
        cidrhost(format("%s/%s", cidrhost(var.rke2_subnet_network_range, 0), split("/", var.rke2_network_range)[1]), 0) == cidrhost(var.rke2_network_range, 0)
      )
      error_message = "The rke2_subnet_network_range (${var.rke2_subnet_network_range}) must be a valid subnet within the rke2_network_range (${var.rke2_network_range})."
    }
  }
}