variable "project_id" {
  type        = string
  description = "The identifier of the project."
}

variable "region" {
  type        = string
  description = "The region for the resources."
  default     = "europe-west4"
}

variable "env" {
  type        = string
  description = "The environment for the resources."
  default     = "dev"
}
