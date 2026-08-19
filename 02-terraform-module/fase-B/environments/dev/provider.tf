# provider.tf
provider "google" {
  alias = "impersonator"
}

data "google_service_account_access_token" "default" {
  provider               = google.impersonator
  target_service_account = "terraform-admin@fase-b-505318.iam.gserviceaccount.com"
  scopes                 = ["userinfo-email", "cloud-platform"]
  lifetime               = "3600s"
}

provider "google" {
  project      = var.project_id
  region       = var.region
  access_token = data.google_service_account_access_token.default.access_token
}

provider "google-beta" {
  project      = var.project_id
  region       = var.region
  access_token = data.google_service_account_access_token.default.access_token
}