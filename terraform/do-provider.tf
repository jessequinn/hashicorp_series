variable "do_token" {
}

variable "ssh_fingerprint" {
  default = "xxxx"
}

variable "server_instance_count" {
  default = "1"
}

variable "client_instance_count" {
  default = "2"
}

variable "do_snapshot_id" {
}

variable "do_region" {
  default = "tor1"
}

variable "do_size" {
  default = "s-1vcpu-1gb"
}

variable "do_private_networking" {
  default = true
}

variable "bastion_droplet_ids" {
}

provider "digitalocean" {
  token = var.do_token
}
