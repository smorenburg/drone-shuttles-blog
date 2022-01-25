# Create the SQL master and replication instances
resource "google_sql_database_instance" "master" {
  name                = "${var.env}-instance-master-${random_id.suffix.hex}"
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

resource "google_sql_database_instance" "replica" {
  name                 = "${var.env}-instance-replica-${random_id.suffix.hex}"
  database_version     = "MYSQL_8_0"
  region               = "europe-north1"
  deletion_protection  = false
  master_instance_name = google_sql_database_instance.master.name

  settings {
    tier = "db-f1-micro"
  }

  replica_configuration {
    failover_target = false
  }
}

# Create the SQL database and user.
resource "google_sql_database" "ghost" {
  name     = "ghost"
  instance = google_sql_database_instance.master.name
}

resource "google_sql_user" "ghost" {
  name     = "ghost"
  instance = google_sql_database_instance.master.name
}