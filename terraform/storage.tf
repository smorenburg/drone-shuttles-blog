# Create the content storage bucket and set permissions.
resource "google_storage_bucket" "content" {
  name                        = "${var.project_id}-${var.env}-content"
  location                    = "eur4"
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "content_public" {
  bucket = google_storage_bucket.content.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket_iam_member" "ghost_object_creator" {
  bucket = google_storage_bucket.content.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.ghost.email}"
}
