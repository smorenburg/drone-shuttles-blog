resource "google_monitoring_custom_service" "blog" {
  service_id   = var.env
  display_name = var.env
}
