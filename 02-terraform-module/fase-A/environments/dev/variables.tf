variable "project_id" {
  description = "The ID of the project"
  type        = string
}

variable "application_name" {
  description = "The name of the application"
  type        = string
}

variable "region" {
  description = "The region where the resources will be created"
  type        = string
}

variable "subnet_ip_range" {
  description = "The IP range for the subnet"
  type        = string
}

variable "image_family" {
  description = "The image family for the VM instance"
  type        = string
}

variable "zone" {
  description = "The zone where the VM instance will be created"
  type        = string
} 

variable "startup_script" {
  description = "The startup script for the VM instance"
  type        = string
  default     = ""
}

variable "db_version" {
  description = "The version of the database"
  type        = string
}

variable "db_edition" {
  description = "The edition of the database"
  type        = string
}

variable "db_tier" {
  description = "The tier of the database"
  type        = string
}

variable "db_deletion_protection" {
  description = "Whether to enable deletion protection for the database"
  type        = bool
}

variable "db_ipv4_enabled" {
  description = "Whether to enable IPv4 for the database"
  type        = bool
}

variable "db_backup_enabled" {
  description = "Whether to enable backups for the database"
  type        = bool
}

variable "db_backup_location" {
  description = "The location for database backups"
  type        = string
}

variable "db_binary_log_enabled" {
  description = "Whether to enable binary logging for the database"
  type        = bool
}

variable "db_backup_start_time" {
  description = "The start time for database backups"
  type        = string
}

variable "db_transaction_log_retention_days" {
  description = "The number of days to retain transaction logs for the database"
  type        = number
}
variable "env" {
  description = "The environment (e.g., dev, staging, prod)"
  type        = string
}
variable "db_point_in_time_recovery_enabled" {
  description = "Whether to enable point-in-time recovery for the database"
  type        = bool
}