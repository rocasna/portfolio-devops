variable "env" {
  description = "The environment for the resources"
  type        = string
  default     = "dev"
}

variable "project_id" {
  description = "The ID of the project"
  type        = string
}

variable "application_name" {
  description = "The name of the application"
  type        = string
  default     = "fase-a"
}

variable "region" {
  description = "The region for the resources"
  type        = string
  default     = "europe-west1"
}

variable "subnet_ip_range" {
  description = "The IP range for the subnet"
  type        = string
}