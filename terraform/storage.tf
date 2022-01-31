# Create the content storage bucket and set permissions.
resource "google_storage_bucket" "content" {
  name                        = "${var.project_id}-${var.env}-content"
  location                    = "eur4"
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
  name     = "${var.project_id}-${var.env}-functions"
  location                    = "europe-west1"
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "posts" {
  name   = "2201311830_posts.zip"
  bucket = google_storage_bucket.functions.name
  source = "./functions/2201311830_posts.zip"
}
