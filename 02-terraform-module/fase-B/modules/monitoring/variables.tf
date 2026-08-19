variable "project_id" {
  type = string
}

variable "env" {
  type = string
}

variable "application_name" {
  type = string
}

variable "host" {
  description = "Public host/IP to hit for the uptime check (the Load Balancer IP)"
  type        = string
}

variable "check_path" {
  description = "Path the uptime check requests to verify a real dependency (e.g. the DB)"
  type        = string
  default     = "/db-status"
}

variable "notification_email" {
  description = "Email address notified when the uptime check fails"
  type        = string
}
