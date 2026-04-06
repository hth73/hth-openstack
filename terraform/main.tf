# ---------------------------------------------------------------------------------
# defines the openstack instance
# ---------------------------------------------------------------------------------
resource "openstack_compute_instance_v2" "webserver" {
  name            = var.instance_name
  image_id        = data.openstack_images_image_v2.webserver.id
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.webserver.name
  security_groups = var.security_groups

  network {
    uuid = data.openstack_networking_network_v2.webserver.id
  }

  # root disk (image)
  block_device {
    uuid                  = data.openstack_images_image_v2.webserver.id
    source_type           = "image"
    destination_type      = "local"
    boot_index            = 0
    delete_on_termination = true
  }

  # data volume (/mnt/data)
  block_device {
    uuid                  = var.volume_id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = -1
    delete_on_termination = false
  }

  user_data = <<-EOF
  #cloud-config
  hostname: ${var.instance_name}

  runcmd:
    - until [ -b /dev/vdb ]; do sleep 1; done
    - mkdir -p /mnt/data
    - blkid /dev/vdb | grep -q UUID || mkfs.ext4 /dev/vdb
    - mountpoint -q /mnt/data || mount /dev/vdb /mnt/data
    - chown www-data:www-data /mnt/data
    - chmod 0755 /mnt/data
    - UUID=$(blkid -s UUID -o value /dev/vdb)
    - grep -q /mnt/data /etc/fstab || echo "UUID=$UUID /mnt/data ext4 defaults,nofail 0 2" >> /etc/fstab
    - systemctl start nginx
  EOF
}

# ---------------------------------------------------------------------------------
# specifies the openstack ssh key pair for the instance
# ---------------------------------------------------------------------------------
resource "openstack_compute_keypair_v2" "webserver" {
  name       = "terraform-ssh-key"
  public_key = file("${path.module}/${var.ssh_public_key_path}")
}

# ---------------------------------------------------------------------------------
# creates a floating IP in openStack and attach it to the instance
# ---------------------------------------------------------------------------------
resource "openstack_networking_floatingip_v2" "webserver" {
  pool = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "webserver" {
  floating_ip = openstack_networking_floatingip_v2.webserver.address
  instance_id = openstack_compute_instance_v2.webserver.id
}
