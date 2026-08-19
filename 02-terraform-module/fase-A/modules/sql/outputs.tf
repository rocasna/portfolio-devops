output "db_instance_private_ip" {
  value = google_sql_database_instance.instance.private_ip_address
}
output "db_instance_name" {
  value = google_sql_database_instance.instance.name
}
output "sql_service_account_email" {
  value = google_sql_database_instance.instance.service_account_email_address
}