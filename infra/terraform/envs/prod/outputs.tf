output "vm_external_ip" {
  value = yandex_vpc_address.this.external_ipv4_address[0].address
}

output "vm_internal_ip" {
  value = yandex_compute_instance.k3s.network_interface[0].ip_address
}

output "vm_name" {
  value = yandex_compute_instance.k3s.name
}
