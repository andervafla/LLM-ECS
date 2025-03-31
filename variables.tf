variable "db_username" {
  type = string
  description = "Database username"
}

variable "db_password" {
  type = string
  description = "Database password"
  sensitive = true
}

variable "db_allocated_storage" {
  type        = number
  default     = 20
  description = "DB size"
}

variable "ollama_image" {
  description = "The container image for ollama"
  type        = string
  default     = "590183928377.dkr.ecr.us-east-1.amazonaws.com/ollama:latest"
}
