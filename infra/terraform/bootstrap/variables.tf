variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "service_account_key_file" {
  type      = string
  sensitive = true
}
