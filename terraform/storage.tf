# Create the content storage bucket and set permissions.
resource "google_storage_bucket" "content" {
  name                        = "${var.project_id}-${var.env}-content"
  location                    = "eu"
  force_destroy               = true
  uniform_bucket_level_access = true
  # checkov:skip=CKV_GCP_62: Publicly accessible storage bucket, no need for additional logging.
}

resource "google_storage_bucket_iam_member" "content_public" {
  bucket = google_storage_bucket.content.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
  # checkov:skip=CKV_GCP_28: Publicly accessible storage bucket.
}

resource "google_storage_bucket_iam_member" "ghost_object_creator" {
  bucket = google_storage_bucket.content.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.ghost.email}"
}

# Create the functions storage bucket and upload object.
resource "google_storage_bucket" "functions" {
  name                        = "${var.project_id}-${var.env}-functions"
  location                    = "eu"
  force_destroy               = true
  uniform_bucket_level_access = true
  # checkov:skip=CKV_GCP_62: Functions storage bucket, no need for additional logging.
}

resource "google_storage_bucket_object" "posts" {
  name   = "${local.object_name}.zip"
  bucket = google_storage_bucket.functions.name
  source = "./functions/${local.object_name}.zip"
}
