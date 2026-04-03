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
