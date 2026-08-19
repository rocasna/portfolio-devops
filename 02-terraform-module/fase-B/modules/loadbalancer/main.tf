resource "google_compute_health_check" "http_health_check" {
  project = var.project_id
  name    = "${var.env}-${var.application_name}-hc"

  http_health_check {
    port = 80
    request_path = "/health"
  }

  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

resource "google_compute_backend_service" "backend" {
  project       = var.project_id
  name          = "${var.env}-${var.application_name}-backend"
  protocol      = "HTTP"
  health_checks = [google_compute_health_check.http_health_check.id]
  security_policy = var.security_policy_id

  backend {
    group = var.instance_group
  }
}

resource "google_compute_url_map" "url_map" {
  project         = var.project_id
  name            = "${var.env}-${var.application_name}-url-map"
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  project = var.project_id
  name    = "${var.env}-${var.application_name}-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  project    = var.project_id
  name       = "${var.env}-${var.application_name}-forwarding-rule"
  target     = google_compute_target_http_proxy.http_proxy.id
  port_range = "80"
}

