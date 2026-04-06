# ---------------------------------------------------------------------------------
# a few output values for verification
# ---------------------------------------------------------------------------------
output "image_name" {
  value = data.openstack_images_image_v2.webserver.name
}

output "image_id" {
  value = data.openstack_images_image_v2.webserver.id
}

output "network_name" {
  value = data.openstack_networking_network_v2.webserver.name
}

output "network_id" {
  value = data.openstack_networking_network_v2.webserver.id
}

output "subnet_name" {
  value = data.openstack_networking_subnet_v2.webserver.name
}

output "subnet_id" {
  value = data.openstack_networking_subnet_v2.webserver.id
}

output "ssh_command" {
   value = "ssh -i ${var.ssh_private_key_path} ubuntu@${openstack_networking_floatingip_v2.webserver.address}"
}
