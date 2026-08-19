variable "project_id" {
  type = string
}

variable "env" {
  type    = string
  default = "dev"
}

variable "application_name" {
  type    = string
  default = "fase-a"
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