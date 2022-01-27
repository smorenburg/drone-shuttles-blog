# Create the service.
resource "google_monitoring_custom_service" "blog" {
  service_id   = var.env
  display_name = var.env
}

# Create the SLOs.
resource "google_monitoring_slo" "request_latency_90" {
  service      = google_monitoring_custom_service.blog.service_id
  slo_id       = "request-latency-90"
  display_name = "90% of the request latency is below 250 ms"

  request_based_sli {
    distribution_cut {
      distribution_filter = "metric.type=\"loadbalancing.googleapis.com/https/total_latencies\" resource.type=\"https_lb_rule\" resource.labels.url_map_name=\"${google_compute_url_map.ghost.name}\""
      range {
        max = 250
      }
    }
  }

  goal                = 0.90
  rolling_period_days = 28
}

resource "google_monitoring_slo" "request_latency_99" {
  service      = google_monitoring_custom_service.blog.service_id
  slo_id       = "request-latency-99"
  display_name = "99% of the request latency is below 500 ms"

  request_based_sli {
    distribution_cut {
      distribution_filter = "metric.type=\"loadbalancing.googleapis.com/https/total_latencies\" resource.type=\"https_lb_rule\" resource.labels.url_map_name=\"${google_compute_url_map.ghost.name}\""
      range {
        max = 500
      }
    }
  }

  goal                = 0.99
  rolling_period_days = 28
}

resource "google_monitoring_slo" "requests_successful" {
  service      = google_monitoring_custom_service.blog.service_id
  slo_id       = "requests-successful"
  display_name = "99% of the requests are successful (availability)"

  request_based_sli {
    good_total_ratio {
      good_service_filter  = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" metric.labels.response_code_class<\"500\" resource.labels.url_map_name=\"${google_compute_url_map.ghost.name}\""
      total_service_filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" resource.labels.url_map_name=\"${google_compute_url_map.ghost.name}\""
    }
  }

  goal                = 0.99
  rolling_period_days = 28
}

# Create the uptime check.
resource "google_monitoring_uptime_check_config" "blog" {
  display_name = local.domain
  timeout      = "60s"
  period       = "60s"

  http_check {
    port         = "443"
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = local.domain
    }
  }
}
