resource "hcloud_network" "rke2_network" {
  name     = "${var.cluster_name}-network"
  ip_range = "10.0.0.0/8"
}

resource "hcloud_network_subnet" "rke2_subnet_eu-central" {
  network_id   = hcloud_network.rke2_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/16"
}
