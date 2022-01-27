variable "project_id" {
  type        = string
  description = "The identifier of the project."
}

variable "region" {
  type        = string
  description = "The region for resources."
  default     = "europe-west4"
}
