output "instance_name" {
  description = "Name of the VM instance"
  value       = google_compute_instance.vm-instance.name
}

output "public_ip" {
  description = "Public IP address of the VM instance"
  value       = google_compute_instance.vm-instance.network_interface[0].access_config[0].nat_ip
}

output "service_account_email" {
  description = "Email of the service account used by the VM"
  value       = google_service_account.compute-instance-sa.email
}