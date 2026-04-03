## required packer plugins for the installation
##
packer {
  required_plugins {
    openstack = {
      source  = "github.com/hashicorp/openstack"
      version = "~> 1.0"
    }
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

source "openstack" "ubuntu-nginx-image" {
  cloud               = "devstack"
  source_image_name   = "ubuntu-24.04-noble-server"
  image_name          = "ubuntu-24.04-nginx-{{timestamp}}"

  flavor              = "ds512M"
  ssh_username        = "ubuntu"

  networks            = ["2350b368-df39-4e4c-ae66-f71fbb34b359"] # dev-vpc
  floating_ip_network = "public"

  security_groups     = ["sg-ssh", "sg-web"]
  ssh_timeout         = "5m"
}

build {
  sources = ["source.openstack.ubuntu-nginx-image"]

  provisioner "ansible" {
    playbook_file = "ansible/playbook.yml"
  }
}
