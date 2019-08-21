resource "openstack_networking_secgroup_v2" "secgroup_baobab" {
  name        = "secgroup_baobab"
  description = "BAOBAB access security group"
}

resource "openstack_networking_secgroup_v2" "secgroup_gen_baobab" {
  name        = "secgroup_gen_baobab"
  description = "My neutron ssh-access security group"
}

module "general_rules" {
  source          = "./modules/network_rules/general"
  secgroup_id   = "${openstack_networking_secgroup_v2.secgroup_gen_baobab.id}"
}

module "baobab_rules" {
  source          = "./modules/network_rules/baobab"
  secgroup_id = "${openstack_networking_secgroup_v2.secgroup_baobab.id}"
}

resource "openstack_compute_keypair_v2" "baobab-keypair" {
  name       = "baobab-keypair"
  public_key = "${file("${var.ssh_key_file}.pub")}"
}

resource "openstack_networking_network_v2" "baobab_network_1" {
  name           = "baobab_network_1"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet_1" {
  name            = "baobab_subnet_1"
  network_id      = "${openstack_networking_network_v2.baobab_network_1.id}"
  cidr            = "10.0.0.0/24"
  ip_version      = 4
  dns_nameservers = ["192.168.2.75", "192.168.2.8"]
}

data "openstack_networking_network_v2" "public_network" {
  name = "${var.public_network}"
}

data "openstack_networking_network_v2" "ceph_network" {
  name = "${var.ceph_network}"
}

resource "openstack_networking_router_v2" "router_1" {
  name                = "router_1"
  admin_state_up      = "true"
  external_network_id = "${data.openstack_networking_network_v2.public_network.id}"
}

resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = "${openstack_networking_router_v2.router_1.id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet_1.id}"
}

resource "openstack_networking_floatingip_v2" "floatip_1" {
  pool = "${var.pool}"
}

resource "openstack_compute_instance_v2" "baobab" {
  name            = "baobab_demo"
  image_id        = "${var.image_id}"
  flavor_name     = "${var.flavor}"
  key_pair        = "${openstack_compute_keypair_v2.baobab-keypair.name}"
  security_groups = ["default", "secgroup_baobab", "secgroup_gen_baobab"]
  user_data       = "#cloud-config\nhostname: ${var.fqdn} \nfqdn: ${var.fqdn}"
  
  metadata {
    ansible_groups = "baobab"
  }
  network {
    uuid = "${openstack_networking_network_v2.baobab_network_1.id}"
  }
}

resource "openstack_compute_floatingip_associate_v2" "baobab_fip1" {
  floating_ip = "${openstack_networking_floatingip_v2.floatip_1.address}"
  instance_id = "${openstack_compute_instance_v2.baobab.id}"

  connection {
    host        = "${openstack_networking_floatingip_v2.floatip_1.address}"
    user        = "${var.ssh_user_name}"
    private_key = "${file(var.ssh_key_file)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update; sleep 5",
      "sudo apt-get install -y python",      
    ]
  }

}
