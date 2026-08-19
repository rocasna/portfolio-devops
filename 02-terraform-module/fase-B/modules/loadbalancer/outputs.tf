output "load_balancer_ip" {
  description = "Public IP address of the Load Balancer"
  value       = google_compute_global_forwarding_rule.forwarding_rule.ip_address
}