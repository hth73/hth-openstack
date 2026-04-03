# Search for ubuntu nginx image
data "openstack_images_image_v2" "nginx" {
  name_regex  = "^ubuntu-24\\.04-nginx-.*"
  most_recent = true

  visibility  = "private"
}
