resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "${var.env}-${var.application_name}-email-alert"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_uptime_check_config" "db_status" {
  project      = var.project_id
  display_name = "${var.env}-${var.application_name}-db-status-check"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = var.check_path
    port         = "80"
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.host
    }
  }
}

resource "google_monitoring_alert_policy" "db_status_down" {
  project      = var.project_id
  display_name = "${var.env}-${var.application_name}-db-status-alert"
  combiner     = "OR"

  conditions {
    display_name = "db-status uptime check failing"

    condition_threshold {
      filter          = "resource.type = \"uptime_url\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.label.\"check_id\" = \"${google_monitoring_uptime_check_config.db_status.uptime_check_id}\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 1

      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.*"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]
}
