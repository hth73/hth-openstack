# ---------------------------------------------------------------------------------
# the current image name is searched for
# ---------------------------------------------------------------------------------
data "openstack_images_image_v2" "webserver" {
  name_regex  = var.image_regex
  most_recent = true
  visibility  = "private"
}

# ---------------------------------------------------------------------------------
# existing network name for the deployment
# ---------------------------------------------------------------------------------
data "openstack_networking_network_v2" "webserver" {
  name = var.network_name
}

# ---------------------------------------------------------------------------------
# existing subnet name for the deployment
# ---------------------------------------------------------------------------------
data "openstack_networking_subnet_v2" "webserver" {
  name = var.subnet_name
}
