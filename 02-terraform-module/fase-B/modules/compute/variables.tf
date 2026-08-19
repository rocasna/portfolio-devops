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

variable "machine_type" {
  type    = string
  default = "e2-small"
}

variable "zone" {
  type = string
}

variable "network_id" {
  description = "The VPC network ID from the network module"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID from the network module"
  type        = string
}

variable "image_family" {
  description = "The image family for the VM instance"
  type        = string
}

variable "startup_script" {
  description = "The startup script for the VM instance"
  type        = string
  default     = ""
}

variable "target_size" {
  description = "The target size for the managed instance group"
  type        = number
  default     = 1
}

variable "canary_startup_script" {
  description = "Startup script for the canary template. Null disables canary (single stable version)."
  type        = string
  default     = null
}

variable "canary_instance_count" {
  description = "Fixed number of instances to run on the canary template (0 disables canary rollout)"
  type        = number
  default     = 0
}