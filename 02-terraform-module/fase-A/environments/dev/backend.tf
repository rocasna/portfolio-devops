# backend.tf
terraform {
  backend "gcs" {
    bucket                      = "fase-a-terraform-state"
    prefix                      = "dev"
    impersonate_service_account = "terraform-admin@fase-a-504618.iam.gserviceaccount.com"
  }
}