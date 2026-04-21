data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

resource "yandex_vpc_network" "this" {
  name = "${local.project_name}-network"
}

resource "yandex_vpc_subnet" "this" {
  name           = "${local.project_name}-subnet-a"
  zone           = var.zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = ["10.10.10.0/24"]
}

resource "yandex_vpc_address" "this" {
  name = "${local.project_name}-public-ip"
  external_ipv4_address {
    zone_id = var.zone
  }
}

resource "yandex_compute_instance" "k3s" {
  name        = "${local.project_name}-vm"
  hostname    = "podinfo-diploma"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id      = yandex_vpc_subnet.this.id
    nat            = true
    nat_ip_address = yandex_vpc_address.this.external_ipv4_address[0].address
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      vm_user        = local.vm_user
      ssh_public_key = trimspace(file(var.ssh_public_key_path))
    })
    serial-port-enable = 1
  }

  scheduling_policy {
    preemptible = true
  }
}
