module "vm" {
  source = "../../modules/vm"

  name          = var.vm_name
  environment   = var.env
  zone          = var.zone
  cores         = var.cores
  memory_gb     = var.memory_gb
  core_fraction = var.core_fraction
  preemptible   = var.preemptible

  image_id          = var.image_id
  boot_disk_size_gb = var.boot_disk_size_gb
  data_disk_size_gb = var.data_disk_size_gb

  create_network        = var.create_network
  subnet_cidr           = var.subnet_cidr
  create_security_group = var.create_security_group
  ssh_ingress_cidr      = var.ssh_ingress_cidr

  ssh_public_key = var.ssh_public_key
  description    = var.description

  labels = var.labels
}
