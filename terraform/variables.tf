# ---------------------------------------------------------------------------------
# defines the terraform script variables
# ---------------------------------------------------------------------------------
variable "instance_name" {
  type        = string
  description = "Name of the instance"
  default     = "vm-nginx-1"
}

variable "image_regex" {
  type    = string
  default = "^ubuntu-24\\.04-.*"
}

variable "flavor_name" {
  type        = string
  description = "Image Flavor"
  default     = "ds512M"
}

variable "network_name" {
  type        = string
  description = "openstack network name"
  default     = "dev-vpc"
}

variable "subnet_name" {
  type        = string
  description = "openstack subnet name"
  default     = "dev-subnet"
}

variable "security_groups" {
  type = list(string)
  default = ["sg-ssh", "sg-web"]
}

variable "volume_id" {
  type        = string
  description = "volume id"
  default     = "3735ec13-5808-42ff-991d-7cd229d0629d"
}

variable "floating_ip_pool" {
  type        = string
  description = "Floating IP Address Pool"
  default     = "public"
}

variable "ssh_public_key_path" {
  type        = string
  description = "sss public key"
  default     = "assets/terraform.pub"
}

variable "ssh_private_key_path" {
  type        = string
  description = "ssh private key"
  default     = "assets/terraform"
}
