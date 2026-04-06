# ---------------------------------------------------------------------------------
# define required providers
# ---------------------------------------------------------------------------------
terraform {
  required_version = ">= 0.14.0"
    required_providers {
        openstack = {
        source    = "terraform-provider-openstack/openstack"
        version   = "~> 1.53.0"
        }
    }
}

# ---------------------------------------------------------------------------------
# configure the openstack provider
# ---------------------------------------------------------------------------------
provider "openstack" {
  auth_url      = "http://192.168.178.54/identity"
  tenant_name   = "dev"
  user_name     = "dev-user"
  password      = "secret"
  region        = "RegionOne"
  endpoint_type = "public"
}
