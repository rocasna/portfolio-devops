variable "impersonate_sa" {
  description = "Service account to impersonate (empty = no impersonation, use direct credentials)"
  type        = string
  default     = ""
}

provider "google" {
  alias = "impersonator"
}

data "google_service_account_access_token" "default" {
  count                   = var.impersonate_sa != "" ? 1 : 0
  provider                = google.impersonator
  target_service_account  = var.impersonate_sa
  scopes                  = ["userinfo-email", "cloud-platform"]
  lifetime                = "3600s"
}

provider "google" {
  project      = var.project_id
  region       = var.region
  access_token = var.impersonate_sa != "" ? data.google_service_account_access_token.default[0].access_token : null
}

provider "google-beta" {
  project      = var.project_id
  region       = var.region
  access_token = var.impersonate_sa != "" ? data.google_service_account_access_token.default[0].access_token : null
}