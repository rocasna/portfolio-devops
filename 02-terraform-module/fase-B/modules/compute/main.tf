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

locals {
  templates = merge(
    { stable = var.startup_script },
    var.canary_startup_script != null ? { canary = var.canary_startup_script } : {}
  )
}

resource "google_compute_instance_template" "templates" {
  for_each     = local.templates
  project      = var.project_id
  name_prefix = each.key == "stable" ? "${var.env}-${var.application_name}-template-" : "${var.env}-${var.application_name}-${each.key}-template-"
  description = each.key == "stable" ? "This template is used to create app server instances." : "Canary template used to create app server instances."
  metadata_startup_script = each.value
  tags = ["fase-b", "portfolio"]

  labels = {
    environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }

  instance_description = "description assigned to instances"
  machine_type         = var.machine_type
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image      = var.image_family
    type              = "PERSISTENT"
    auto_delete       = true
    boot              = true
  }

  network_interface {
    network = var.network_id
    subnetwork = var.subnet_id
  }

  service_account {
    email  = google_service_account.compute-instance-sa.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance_group_manager" "mig" {
  project      = var.project_id
  name         = "${var.env}-${var.application_name}-igm"
  base_instance_name = "${var.env}-${var.application_name}-instance"
  zone         = var.zone

named_port {
  name = "http"
  port = 80
}

  version {
    name              = "stable"
    instance_template = google_compute_instance_template.templates["stable"].id
  }

  dynamic "version" {
    for_each = contains(keys(local.templates), "canary") ? [1] : []
    content {
      name              = "canary"
      instance_template = google_compute_instance_template.templates["canary"].id
      target_size {
        fixed = var.canary_instance_count
      }
    }
  }

  target_size = var.target_size
}

