variable "web_server_rg" {
  description = "The resource group"
  default     = "my_rg"
}

variable "resource_prefix" {
  description = "prefix to add to all objects created"
  default     = ""
}

variable "web_server_name" {
  description = "The web server name"
  default     = "my_web_server"
}

variable "environment" {
  description = "The deployment environment name"
  default     = "development"
}

variable "web_server_count"{
  description = "The number of webservers"
  default     = 0
}

variable "terraform_script_version" {
  description = "Version of this code"
  default = "0.00"
}

variable "domain_name_label" {
  description = "The DNS label"
  default     = "my-web"
}

variable "web_server_location" {
  description = "The location of the webserver"
  default     = "westus2"
}

variable "web_server_subnets" {
  description = "The subnet list"
  default     = []
}

variable "web_server_address_space" {
  description = "The VNet CIDRs"
  default     = []
}