# Create the service account and set permissions.
resource "google_service_account" "posts" {
  account_id = "${var.env}-posts-${local.region_suffix}"
}

resource "google_project_iam_member" "posts_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.posts.email}"
}

# Create the function using the functions/posts.zip object.
resource "google_cloudfunctions_function" "posts_delete_all" {
  name                  = "posts-delete-all-function"
  region                = var.region
  runtime               = "go116"
  service_account_email = google_service_account.posts.email

  source_archive_bucket = google_storage_bucket.functions.name
  source_archive_object = google_storage_bucket_object.posts.name

  available_memory_mb = 128
  trigger_http        = true
  entry_point         = "DeleteAll"

  environment_variables = {
    DB_USERNAME              = google_sql_user.ghost.name
    INSTANCE_CONNECTION_NAME = google_sql_database_instance.master.connection_name
    DB_NAME                  = google_sql_database.ghost.name
  }
}
