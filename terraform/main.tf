terraform {
  required_version = "~> 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.7.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "4.7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
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

locals {
  # Set the region suffix, ew4 for europe-west4, and en1 for europe-north1.
  region_suffix = var.region == "europe-west4" ? "ew4" : "en1"

  # Set the local domain variable for the SSL certificate, load balancer (header), and Ghost URL.
  domain = "${var.env}.${google_compute_global_address.ghost.address}.nip.io"

  # Render the cloud-init cloud-config YAML template using variables.
  cloud_config = templatefile("./templates/cloud-config.yaml", local.vars)

  vars = {
    project_id           = var.project_id
    registry             = var.env == "stage" || var.env == "prod" ? "release" : var.env
    sql_proxy_version    = "1.28.0"
    sql_proxy_instances  = google_sql_database_instance.master.connection_name
    ghost_version        = var.ghost_version
    ghost_content_bucket = google_storage_bucket.content.name
    ghost_url            = "https://${local.domain}"
  }
}

# Generate a random suffix for the SQL instances.
resource "random_id" "suffix" {
  byte_length = 2
}

# Generate a random password for the posts user and write to secret manager.
resource "random_password" "posts" {
  length  = 16
  special = true
}

resource "google_secret_manager_secret" "posts_password" {
  secret_id = "posts-password"

  labels = {
    username = "posts"
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

resource "google_secret_manager_secret_version" "posts_password" {
  secret      = google_secret_manager_secret.posts_password.id
  secret_data = random_password.posts.result
}
