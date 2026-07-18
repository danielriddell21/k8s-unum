resource "hcloud_ssh_key" "unum" {
  name       = "unum-key"
  public_key = var.ssh_public_key
}

resource "hcloud_server" "unum" {
  name        = "unum"
  server_type = "cx33"
  image       = "ubuntu-24.04"
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.unum.id]

  user_data = <<-EOT
    #cloud-config
    package_update: true
    packages:
      - curl
    runcmd:
      - curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
  EOT
}
