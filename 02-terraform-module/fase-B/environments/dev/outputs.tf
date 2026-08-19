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
output "env" {
  value = var.env
}
output "machine_type" {
  value = var.machine_type
}
output "target_size" {
  value = var.target_size
}

output "db_connection_name" {
  description = "Cloud SQL connection name (project:region:instance) for the Auth Proxy / Python Connector"
  value       = module.sql.db_connection_name
}

output "db_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = module.sql.db_instance_private_ip
}

output "vm_service_account_email" {
  description = "Email of the VM's service account, used as the Cloud SQL IAM DB user"
  value       = module.compute.service_account_email
}

output "instance_group_manager_name" {
  description = "Name of the managed instance group, used for rolling-action replace"
  value       = module.compute.instance_group_manager_name
}

output "load_balancer_ip" {
  description = "Public IP address of the Load Balancer"
  value       = module.loadbalancer.load_balancer_ip
}