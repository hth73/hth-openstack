# Define required providers
terraform {
  required_version = ">= 0.14.0"
    required_providers {
        openstack = {
        source    = "terraform-provider-openstack/openstack"
        version   = "~> 1.53.0"
        }
    }
}

# Configure the OpenStack Provider
provider "openstack" {
  auth_url    = "http://cloud.htdom.local/identity"
  tenant_name = "dev"
  user_name   = "dev-user"
  password    = "secret"
  region      = "RegionOne"
}

# Search for image
data "openstack_images_image_v2" "nginx" {
  name_regex  = "^ubuntu-24\\.04-nginx-.*"
  most_recent = true

  visibility  = "private"
}

output "image_name" {
  value = data.openstack_images_image_v2.nginx.name
}

output "image_id" {
  value = data.openstack_images_image_v2.nginx.id
}
