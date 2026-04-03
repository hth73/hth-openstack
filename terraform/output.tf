output "image_name" {
  value = data.openstack_images_image_v2.nginx.name
}

output "image_id" {
  value = data.openstack_images_image_v2.nginx.id
}
