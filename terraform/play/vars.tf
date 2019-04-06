variable "web_server_location" {
  description = "The region for deployment"
  default     = "australiacentral"
}

variable "web_server_rg" {
  description = "The resource group"
  default     = "my_rg"
}

variable "resource_prefix" {
  description = "prefix to add to all objects created"
  default     = ""
}

variable "web_server_address_space" {
  description = "VNet CIDR range"
  default     = "0.0.0.0/22"
}

variable "web_server_address_prefix" {
  description = "Subnet CIDR range"
  default     = "0.0.1.0/24"
}

variable "web_server_name" {
  description = "The web server name"
  default     = "my_web_server"
}

variable "environment" {
  description = "The deployment environment name"
  default     = "development"
}