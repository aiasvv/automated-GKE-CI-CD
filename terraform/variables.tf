variable "project" {
  description = "The project ID"
  type        = string
  default     = "aia-project-435110"
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-central1-c"
}

variable "service_account" {
  description = "The email of the service account"
  type        = string
  default     = "new-sa@aia-project-435110.iam.gserviceaccount.com"
}

variable "oauth_scopes" {
  description = "List of OAuth scopes for GKE node pools."
  type        = list(string)
  default     = [
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}