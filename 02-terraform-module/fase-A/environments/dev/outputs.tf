output "project_id" {
  value = var.project_id
}
output "application_name" {
  value = var.application_name
}
output "region" {
  value = var.region
}
output "subnet_ip_range" {
  value = var.subnet_ip_range
}
output "image_family" {
  value = var.image_family
}
output "zone" {
  value = var.zone
}
output "startup_script" {
  value = var.startup_script
}
output "vm_public_ip" {
  value       = module.compute.public_ip
}
output "env" {
  value = var.env
}