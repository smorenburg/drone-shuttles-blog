variable "project_id" {
  type        = string
  description = "The identifier of the project."
}

variable "region" {
  type        = string
  description = "The region for resources."
  default     = "europe-west4"
}

variable "env" {
  type        = string
  description = "The environment for the resources."
  default     = "dev"
}

variable "ghost_version" {
  type        = string
  description = "The version of the Ghost image."
  default     = "latest"
}

variable "machine_type" {
  type        = string
  description = "The compute instance machine type."
  default     = "e2-small"
}

variable "sql_tier" {
  type        = string
  description = "The SQL instance tier."
  default     = "db-g1-small"
}
