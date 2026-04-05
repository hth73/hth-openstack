## required packer plugins for the installation
##
packer {
  required_plugins {
    openstack = {
      source  = "github.com/hashicorp/openstack"
      version = "~> 1.0"
    }
    ansible   = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

## Packer Variables
##
variable "os_version" {
  type    = string
  default = "ubuntu-24.04"
}

variable "flavor" {
  type    = string
  default = "ds512M"
}

## Source Image
##
source "openstack" "ubuntu-nginx-image" {
  cloud             = "devstack"

  source_image_name = "${var.os_version}-noble-server"
  image_name        = "${var.os_version}-${formatdate("YYYY-MM-DD", timestamp())}"

  flavor       = var.flavor
  ssh_username = "ubuntu"

  networks            = ["2350b368-df39-4e4c-ae66-f71fbb34b359"]
  floating_ip_network = "public"

  security_groups = ["sg-ssh", "sg-web"]
  ssh_timeout     = "5m"
}

## Build Process
##
build {
  sources = ["source.openstack.ubuntu-nginx-image"]

  provisioner "ansible" {
    playbook_file = "ansible/playbook.yml"

    ansible_env_vars = [
      "ANSIBLE_ROLES_PATH=../common/ansible/roles"
    ]

    use_proxy = false
  }
}
