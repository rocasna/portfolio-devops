resource "google_service_account" "compute-instance-sa" {
  account_id   = "${var.env}-${var.application_name}-sa"
  project      = var.project_id
  description  = "Service account for VM Instance"
  display_name = "Custom SA for VM Instance"
}

resource "google_service_account_iam_member" "terraform_admin_sa_user" {
  service_account_id = google_service_account.compute-instance-sa.name
  role                = "roles/iam.serviceAccountUser"
  member              = "serviceAccount:terraform-admin@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.compute-instance-sa.email}"
}

resource "google_project_iam_member" "sql_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.compute-instance-sa.email}"
}

resource "google_compute_instance" "vm-instance" {
  name         = "${var.env}-${var.application_name}-instance"
  project      = var.project_id
  machine_type = var.machine_type
  zone         = var.zone
  metadata_startup_script = var.startup_script

  tags = [var.env, var.application_name]

  boot_disk {
    initialize_params {
      image = var.image_family
      labels = {
        my_label = "vm-instance"
      }
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.subnet_id

    access_config {
      // Ephemeral public IP
    }
  }

  service_account {
    email  = google_service_account.compute-instance-sa.email
    scopes = ["cloud-platform"]
  }
}