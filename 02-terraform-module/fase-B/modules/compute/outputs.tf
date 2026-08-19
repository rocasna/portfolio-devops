output "instance_name" {
  description = "Name of the VM instance"
  value       = google_compute_instance_template.templates["stable"].name
}

output "service_account_email" {
  description = "Email of the service account used by the VM"
  value       = google_service_account.compute-instance-sa.email
}

output "instance_group_manager_name" {
  description = "Name of the managed instance group, used to target rolling replaces/updates"
  value       = google_compute_instance_group_manager.mig.name
}

output "instance_group_manager_self_link" {
  description = "Self link of the managed instance group"
  value       = google_compute_instance_group_manager.mig.self_link
}

output "instance_group" {
  description = "Instance group URL from the MIG, used as backend for the Load Balancer"
  value       = google_compute_instance_group_manager.mig.instance_group
}