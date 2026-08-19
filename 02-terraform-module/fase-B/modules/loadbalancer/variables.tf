variable "project_id" {
  type = string
}

variable "env" {
  type    = string
  default = "dev"
}

variable "application_name" {
  type    = string
  default = "fase-b"
}

variable "instance_group" {
  description = "Instance group from the MIG (compute module)"
  type        = string
}

variable "security_policy_id" {
  description = "Cloud Armor security policy ID to attach to the backend service"
  type        = string
  default     = null
}