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