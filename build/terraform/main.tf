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
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

resource "google_cloudbuild_trigger" "demo-ci" {
  name = "demo-ci"

  github {
    name  = "drone-shuttles-blog"
    owner = "smorenburg"

    push {
      branch = "^dev$"
    }
  }

  included_files = ["src/**", "terraform/**"]

  substitutions = {
    _ENV      = "dev"
    _REGISTRY = "dev"
  }

  filename = "build/triggers/env-ci.yaml"
}

resource "google_cloudbuild_trigger" "demo-plan" {
  name = "demo-plan"

  github {
    name  = "drone-shuttles-blog"
    owner = "smorenburg"

    push {
      branch = "^dev$"
    }
  }

  ignored_files = ["**/**"]

  substitutions = {
    _ENV          = "dev"
    _MACHINE_TYPE = "e2-small"
    _SQL_TIER     = "db-g1-small"
  }

  filename = "build/triggers/env-plan.yaml"
}

resource "google_cloudbuild_trigger" "demo-cd" {
  name = "demo-cd"

  github {
    name  = "drone-shuttles-blog"
    owner = "smorenburg"

    push {
      branch = "^dev$"
    }
  }

  ignored_files = ["**/**"]

  substitutions = {
    _ENV          = "dev"
  }

  filename = "build/triggers/env-plan.yaml"
}
