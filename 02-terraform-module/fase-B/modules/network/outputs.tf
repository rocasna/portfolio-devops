output "network_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.vpc_network.id
}

output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = google_compute_subnetwork.subnet.id
}

output "private_vpc_connection_id" {
  description = "ID of the private VPC connection for Cloud SQL peering"
  value = google_service_networking_connection.private_vpc_connection.id
}

