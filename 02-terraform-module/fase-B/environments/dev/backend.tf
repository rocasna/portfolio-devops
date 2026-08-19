# backend.tf
terraform {
  backend "gcs" {
    bucket                      = "fase-b-terraform-state"
    prefix                      = "dev"
    impersonate_service_account = "terraform-admin@fase-b-505318.iam.gserviceaccount.com"
  }
}