terraform {
  backend "gcs" {
    bucket = "fase-a-terraform-state"
    prefix = "dev"
  }
}