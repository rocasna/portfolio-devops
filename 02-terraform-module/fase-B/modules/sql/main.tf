resource "google_sql_database_instance" "instance" {
  name             = "${var.env}-${var.application_name}-db"
  region           = var.region
  database_version = var.db_version

  depends_on = [var.private_vpc_connection_id]

  deletion_protection = var.db_deletion_protection

  settings {
    edition = var.db_edition
    tier    = var.db_tier

    deletion_protection_enabled =  var.db_deletion_protection

    database_flags {
      name  = "cloudsql_iam_authentication"
      value = "on"
    }

    ip_configuration {
      ipv4_enabled                                  = var.db_ipv4_enabled
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = var.db_backup_enabled
      location                       = var.db_backup_location
      binary_log_enabled             = var.db_binary_log_enabled
      start_time                     = var.db_backup_start_time
      transaction_log_retention_days = var.db_transaction_log_retention_days
    }
  }
}

resource "google_sql_user" "db_iam_user" {
  name     = var.vm_service_account_email
  instance = google_sql_database_instance.instance.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}