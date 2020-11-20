resource "digitalocean_droplet" "server" {
  count               = var.server_instance_count
  name                = "server-${count.index + 1}"
  tags                = ["nomad", "server"]
  image               = var.do_snapshot_id
  region              = var.do_region
  size                = var.do_size
  private_networking  = var.do_private_networking
  ssh_keys            = [var.ssh_fingerprint]

  connection {
    type              = "ssh"
    user              = "root"
    host              = self.ipv4_address
    agent             = true
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/node_number/${count.index + 1}/g' /etc/systemd/system/consul-server.service",
      "sed -i 's/server_count/${var.server_instance_count}/g' /etc/systemd/system/consul-server.service",
      "chmod +x /root/configure_consul.sh",
      "/root/configure_consul.sh server",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "consul join ${digitalocean_droplet.server.0.ipv4_address_private}",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/enable_vault.sh",
      "/root/enable_vault.sh",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 30",
      "chmod +x /root/init_vault.sh",
      "/root/init_vault.sh ${count.index}",
    ]
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no root@${digitalocean_droplet.server.0.ipv4_address}:/root/startupOutput.txt tmp/vaultDetails.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/configure_nomad.sh",
      "sed -i 's/server_ip_bind_addr/0.0.0.0/g' /root/nomad-server.hcl",
      "sed -i 's/server_ip/${self.ipv4_address_private}/g' /root/nomad-server.hcl",
      "sed -i 's/server_count/${var.server_instance_count}/g' /root/nomad-server.hcl",
      "sed -i \"s/replace_vault_token/$(sed -n -e 's/^Initial Root Token: //p' /root/startupOutput.txt)/g\" /etc/systemd/system/nomad-server.service",
      "/root/configure_nomad.sh server",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "export NOMAD_ADDR=http://${self.ipv4_address_private}:4646",
      "nomad server join ${digitalocean_droplet.server.0.ipv4_address_private}",
    ]
  }

  provisioner "local-exec" {
    command = "echo ${digitalocean_droplet.server.0.ipv4_address_private} > tmp/private_server.txt"
  }

  provisioner "local-exec" {
    command = "echo ${digitalocean_droplet.server.0.ipv4_address} > tmp/public_server.txt"
  }
}

resource "null_resource" "dependency_manager" {
  triggers = {
    dependency_id = digitalocean_droplet.server[0].ipv4_address_private
  }
}

resource "digitalocean_droplet" "client" {
  count               = var.client_instance_count
  name                = "client-${count.index + 1}"
  tags                = ["nomad", "client"]
  image               = var.do_snapshot_id
  region              = var.do_region
  size                = var.do_size
  private_networking  = var.do_private_networking
  ssh_keys            = [var.ssh_fingerprint]
  depends_on          = [null_resource.dependency_manager]

  connection {
    type              = "ssh"
    user              = "root"
    host              = self.ipv4_address
    agent             = true
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/node_number/${count.index + 1}/g' /etc/systemd/system/consul-client.service",
      "chmod +x /root/configure_consul.sh",
      "/root/configure_consul.sh client ${digitalocean_droplet.server[0].ipv4_address_private}",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/configure_nomad.sh",
      "/root/configure_nomad.sh client",
    ]
  }
}

//resource "digitalocean_certificate" "cert" {
//  name    = "letsencrypt-1"
//  type    = "lets_encrypt"
//  domains = ["www.jessequinn.info", "jessequinn.info", "www.scidoc.dev", "scidoc.dev"]
//}

//resource "digitalocean_loadbalancer" "public" {
//  name = "loadbalancer-1"
//  region = var.do_region
//
//  forwarding_rule {
//    entry_port = 443
////    entry_protocol = "https"
//    entry_protocol = "http"
//
//    target_port = 9999
//    target_protocol = "http"
//
////    certificate_id = digitalocean_certificate.cert.id
//  }
//
//  forwarding_rule {
//    entry_port = 80
//    entry_protocol = "http"
//
//    target_port = 9999
//    target_protocol = "http"
//  }
//
//  healthcheck {
//    port = 22
//    protocol = "tcp"
//  }
//
//  droplet_ids = concat(digitalocean_droplet.server.*.id, digitalocean_droplet.client.*.id)
//}

resource "digitalocean_firewall" "private" {
  name = "private-firewall-1"

  droplet_ids = concat(digitalocean_droplet.server.*.id, digitalocean_droplet.client.*.id, var.bastion_droplet_ids)

  inbound_rule {
    protocol                  = "tcp"
    port_range                = "22"
    source_addresses          = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol                  = "tcp"
    port_range                = "all"
    source_droplet_ids        = concat(digitalocean_droplet.server.*.id, digitalocean_droplet.client.*.id, var.bastion_droplet_ids)
  }

  inbound_rule {
    protocol                  = "udp"
    port_range                = "all"
    source_droplet_ids        = concat(digitalocean_droplet.server.*.id, digitalocean_droplet.client.*.id, var.bastion_droplet_ids)
  }

  outbound_rule {
    protocol                  = "tcp"
    port_range                = "all"
    destination_addresses     = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol                  = "udp"
    port_range                = "all"
    destination_addresses     = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_firewall" "bastion" {
  name = "bastion-firewall-1"

  droplet_ids = concat(var.bastion_droplet_ids)

  inbound_rule {
    protocol                  = "tcp"
    port_range                = "22"
    source_addresses          = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol                  = "tcp"
    port_range                = "80"
    source_addresses          = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol                  = "tcp"
    port_range                = "443"
    source_addresses          = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol                  = "tcp"
    port_range                = "9200"
    source_addresses          = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol                  = "tcp"
    port_range                = "9202"
    source_addresses          = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol                  = "tcp"
    port_range                = "all"
    destination_addresses     = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol                  = "udp"
    port_range                = "all"
    destination_addresses     = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_firewall" "web" {
  name = "server-firewall-1"

  droplet_ids = concat(digitalocean_droplet.server.*.id)

  inbound_rule {
    protocol                  = "tcp"
    port_range                = "22"
    source_addresses          = ["0.0.0.0/0", "::/0"]
//    source_load_balancer_uids = [digitalocean_loadbalancer.public.id]
  }

  inbound_rule {
    protocol                  = "tcp"
    port_range                = "80"
    source_addresses          = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol                  = "tcp"
    port_range                = "443"
    source_addresses          = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol                  = "tcp"
    port_range                = "all"
    destination_addresses     = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol                  = "udp"
    port_range                = "all"
    destination_addresses     = ["0.0.0.0/0", "::/0"]
  }
}

## Add domain jessequinn.info ##
//resource "digitalocean_domain" "jessequinn" {
//  name       = "jessequinn.info"
////  ip_address = digitalocean_droplet.server[0].ipv4_address
//}

## Add an A record to the domain for www.jessequinn.info ##
resource "digitalocean_record" "www-jessequinn" {
  domain = "jessequinn.info"
  type   = "A"
  name   = "www"
  value  = digitalocean_droplet.server[0].ipv4_address
}

resource "digitalocean_record" "jessequinn" {
  domain = "jessequinn.info"
  type   = "A"
  name   = "@"
  value  = digitalocean_droplet.server[0].ipv4_address
}

## Add domain scidoc.dev ##
//resource "digitalocean_domain" "scidoc" {
//  name       = "scidoc.dev"
////  ip_address = digitalocean_droplet.server[0].ipv4_address
//}

## Add an A record to the domain for www.scidoc.dev ##
resource "digitalocean_record" "www-scidoc" {
  domain = "scidoc.dev"
  type   = "A"
  name   = "www"
  value  = digitalocean_droplet.server[0].ipv4_address
}

resource "digitalocean_record" "scidoc" {
  domain = "scidoc.dev"
  type   = "A"
  name   = "@"
  value  = digitalocean_droplet.server[0].ipv4_address
}


//output "load_balancer_id" {
//  value = digitalocean_loadbalancer.public.id
//}

output "consul_server_ip" {
  value = digitalocean_droplet.server[0].ipv4_address_private
}

output "server_ids" {
  value = [digitalocean_droplet.server.*.id]
}

output "client_ids" {
  value = [digitalocean_droplet.client.*.id]
}
