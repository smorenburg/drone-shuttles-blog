terraform {
  required_version = "~> 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.0"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_project" "project" {}

locals {}

resource "random_id" "suffix" {
  byte_length = 4
}

# Create the VPC network, subnet, and firewall rules.
resource "google_compute_network" "vpc_network" {
  name                    = "vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "default" {
  name                     = "default"
  ip_cidr_range            = "10.0.2.0/23"
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = "0.5"
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_http_ingress" {
  name          = "allow-http-ingress"
  network       = google_compute_network.vpc_network.id
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["2368"]
  }

  target_tags = ["http"]
}

resource "google_compute_firewall" "allow_iap_ingress" {
  name          = "allow-iap-ingress"
  network       = google_compute_network.vpc_network.id
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  target_tags = ["iap"]
}

resource "google_compute_firewall" "allow_health_check_ingress" {
  name          = "allow-health-check-ingress"
  network       = google_compute_network.vpc_network.id
  direction     = "INGRESS"
  target_tags   = ["health-check", "vpc-connector"]
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22", "108.170.220.0/23"]

  allow {
    protocol = "tcp"
  }
}

resource "google_compute_firewall" "allow_internal_ingress" {
  name          = "allow-internal-ingress"
  network       = google_compute_network.vpc_network.id
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = [google_compute_subnetwork.default.ip_cidr_range]

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

# Create the router and router NAT.
resource "google_compute_router" "vpc_router" {
  name    = "vpc-router"
  network = google_compute_network.vpc_network.id
}

resource "google_compute_router_nat" "vpc_router_nat" {
  name                               = "vpc-router-nat"
  router                             = google_compute_router.vpc_router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Create the service account.
resource "google_service_account" "ghost" {
  account_id = "ghost-${random_id.suffix.hex}"
}

# Create the content storage bucket and make public.
resource "google_storage_bucket" "content" {
  name                        = "${var.project_id}-content"
  location                    = "eur4"
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "content_public" {
  bucket = google_storage_bucket.content.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "random_password" "mysql" {
  length  = 16
  special = true
}

resource "google_secret_manager_secret" "mysql_password" {
  secret_id = "mysql-password"

  labels = {
    username = "ghost"
  }

  replication {
    user_managed {
      replicas {
        location = "europe-west4"
      }
      replicas {
        location = "europe-north1"
      }
    }
  }
}

resource "google_secret_manager_secret_version" "mysql_password" {
  secret = google_secret_manager_secret.mysql_password.id

  secret_data = random_password.mysql.result
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.content.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.ghost.email}"
}

resource "google_sql_database_instance" "mysql_master" {
  name                = "mysql-master-${random_id.suffix.hex}"
  database_version    = "MYSQL_8_0"
  region              = "europe-west4"
  deletion_protection = false

  settings {
    tier              = "db-f1-micro"
    availability_type = "REGIONAL"

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }
  }
}

resource "google_sql_database_instance" "mysql_replica" {
  name                 = "mysql-replica-${random_id.suffix.hex}"
  database_version     = "MYSQL_8_0"
  region               = "europe-north1"
  deletion_protection  = false
  master_instance_name = google_sql_database_instance.mysql_master.name

  settings {
    tier = "db-f1-micro"
  }

  replica_configuration {
    failover_target = false
  }
}

resource "google_sql_user" "ghost" {
  name     = "ghost"
  instance = google_sql_database_instance.mysql_master.name
}

resource "google_sql_database" "ghost" {
  name     = "ghost"
  instance = google_sql_database_instance.mysql_master.name
}

locals {
  cloud_config = "./assets/cloud-config.yaml"
}

data "template_file" "cloud_config" {
  template = file(local.cloud_config)

  vars = {
    sql_proxy_version    = "1.28.0"
    sql_proxy_instances  = google_sql_database_instance.mysql_master.connection_name
    ghost_version        = "0.0.7"
    ghost_content_bucket = google_storage_bucket.content.name
  }
}

data "template_cloudinit_config" "default" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_config.rendered
  }
}

resource "google_project_iam_member" "ghost_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.ghost.email}"
}

resource "google_compute_instance" "instance" {
  name                      = "ghost-${random_id.suffix.hex}"
  machine_type              = "e2-medium"
  zone                      = "europe-west4-b"
  allow_stopping_for_update = true
  tags                      = ["iap", "http-server"]

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.default.name

    access_config {
      network_tier = "PREMIUM"
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_integrity_monitoring = true
    enable_vtpm                 = true
  }

  metadata = {
    block-project-ssh-keys = true
    enable-oslogin         = true
    google-logging-enabled = true
    user-data              = data.template_cloudinit_config.default.rendered
  }

  service_account {
    email  = google_service_account.ghost.email
    scopes = ["cloud-platform"]
  }
}
