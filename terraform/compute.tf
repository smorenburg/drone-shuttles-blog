# Create the VPC network and subnet.
resource "google_compute_network" "vpc" {
  name                    = "${var.env}-vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "default_ew4" {
  name                     = "${var.env}-default"
  ip_cidr_range            = "10.1.0.0/24"
  region                   = "europe-west4"
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = "0.5"
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "default_en1" {
  name                     = "${var.env}-default"
  ip_cidr_range            = "10.2.0.0/24"
  region                   = "europe-north1"
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = "0.5"
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Create the firewall rules.
resource "google_compute_firewall" "allow_iap_ingress" {
  name          = "${var.env}-allow-iap-ingress"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  target_tags   = ["instance"]
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }
}

resource "google_compute_firewall" "allow_load_balancer_ingress" {
  name          = "${var.env}-allow-load-balancer-ingress"
  network       = google_compute_network.vpc.id
  description   = "Applies to the request and health check source ranges."
  direction     = "INGRESS"
  target_tags   = ["instance"]
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22", "108.170.220.0/23"]

  allow {
    protocol = "tcp"
  }
}

resource "google_compute_firewall" "allow_internal_ingress" {
  name      = "${var.env}-allow-internal-ingress"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 65534

  source_ranges = [
    google_compute_subnetwork.default_ew4.ip_cidr_range,
    google_compute_subnetwork.default_en1.ip_cidr_range
  ]

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

# Create the router.
resource "google_compute_address" "vpc" {
  name = "${var.env}-vpc-${local.region_suffix}-router-address"
}

resource "google_compute_router" "vpc" {
  name    = "${var.env}-vpc-${local.region_suffix}-router"
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "vpc" {
  name                               = "${var.env}-vpc-${local.region_suffix}-router-nat"
  router                             = google_compute_router.vpc.name
  nat_ip_allocate_option             = "MANUAL_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
  nat_ips                            = [google_compute_address.vpc.self_link]

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Create the health check.
resource "google_compute_health_check" "ghost" {
  name                = "${var.env}-ghost-${local.region_suffix}-health-check"
  check_interval_sec  = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
  timeout_sec         = 2

  tcp_health_check {
    port = 2368
  }
}

# Create the service account and set permissions.
resource "google_service_account" "ghost" {
  account_id = "${var.env}-ghost-${local.region_suffix}"
}

resource "google_project_iam_member" "ghost_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.ghost.email}"
}

resource "google_project_iam_member" "ghost_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.ghost.email}"
}

resource "google_project_iam_member" "ghost_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.ghost.email}"
}

# Creat the instance template.
resource "google_compute_instance_template" "ghost" {
  name_prefix  = "${var.env}-ghost-${local.region_suffix}-template-"
  machine_type = "e2-custom-2-2048"
  tags         = ["instance"]

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image = "cos-cloud/cos-stable"
    disk_type    = "pd-ssd"
    boot         = true
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = var.region == "europe-west4" ? google_compute_subnetwork.default_ew4.name : google_compute_subnetwork.default_en1.name
  }

  lifecycle {
    create_before_destroy = true
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_integrity_monitoring = true
    enable_vtpm                 = true
  }

  metadata = {
    block-project-ssh-keys    = true
    enable-oslogin            = true
    google-logging-enabled    = true
    google-monitoring-enabled = true
    user-data                 = local.cloud_config
  }

  service_account {
    email  = google_service_account.ghost.email
    scopes = ["cloud-platform"]
  }
}

# Create the managed instance group.
resource "google_compute_region_instance_group_manager" "ghost" {
  provider = google-beta

  name               = "${var.env}-ghost-${local.region_suffix}-group"
  base_instance_name = "${var.env}-ghost-${local.region_suffix}-instance"
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.ghost.id
  }

  named_port {
    name = "http"
    port = 2368
  }

  update_policy {
    type                         = "PROACTIVE"
    instance_redistribution_type = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 3
    max_unavailable_fixed        = 3
    min_ready_sec                = 15
    replacement_method           = "SUBSTITUTE"
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.ghost.id
    initial_delay_sec = 180
  }
}

# Create the SSL certificate.
resource "google_compute_managed_ssl_certificate" "ghost" {
  name = "${var.env}-ghost-certificate"

  managed {
    domains = [local.domain]
  }

  depends_on = [google_compute_url_map.ghost]
}

# Create the global load balancer.
resource "google_compute_global_address" "ghost" {
  name = "${var.env}-ghost-address"
}

resource "google_compute_backend_service" "ghost" {
  name                   = "${var.env}-ghost-backend-service"
  load_balancing_scheme  = "EXTERNAL"
  enable_cdn             = true
  health_checks          = [google_compute_health_check.ghost.id]
  port_name              = "http"
  custom_request_headers = ["X-Forwarded-Proto: https", "Host: ${local.domain}"]

  backend {
    group = google_compute_region_instance_group_manager.ghost.instance_group
  }
}

resource "google_compute_url_map" "ghost" {
  name            = "${var.env}-ghost-url-map"
  default_service = google_compute_backend_service.ghost.id
}

resource "google_compute_target_https_proxy" "ghost" {
  name             = "${var.env}-ghost-https-proxy"
  url_map          = google_compute_url_map.ghost.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ghost.id]
}

resource "google_compute_global_forwarding_rule" "ghost" {
  name       = "${var.env}-ghost-forwarding-rule"
  target     = google_compute_target_https_proxy.ghost.id
  port_range = 443
  ip_address = google_compute_global_address.ghost.address
}

resource "google_compute_url_map" "ghost_redirect" {
  name = "${var.env}-ghost-url-map-redirect"

  default_url_redirect {
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
    https_redirect         = true
  }
}

resource "google_compute_target_http_proxy" "ghost_redirect" {
  name    = "${var.env}-ghost-redirect-http-proxy"
  url_map = google_compute_url_map.ghost_redirect.self_link
}

resource "google_compute_global_forwarding_rule" "ghost_redirect" {
  name       = "${var.env}-ghost-redirect-forwarding-rule"
  target     = google_compute_target_http_proxy.ghost_redirect.self_link
  ip_address = google_compute_global_address.ghost.address
  port_range = "80"
}
