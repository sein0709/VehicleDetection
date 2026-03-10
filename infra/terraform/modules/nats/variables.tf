variable "name_prefix" {
  type = string
}

variable "namespace" {
  description = "Kubernetes namespace for NATS"
  type        = string
  default     = "greyeye-data"
}

variable "cluster_size" {
  description = "Number of NATS server replicas (R=3 for production)"
  type        = number
  default     = 3
}

variable "storage_size" {
  description = "PVC size for JetStream file store per node"
  type        = string
  default     = "50Gi"
}
