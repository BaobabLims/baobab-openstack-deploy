data "openstack_networking_network_v2" "baobab" {
  name = "${var.pool}"
}
