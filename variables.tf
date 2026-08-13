variable "subscription_id" {
  description = "Azure subscription in which the lab resources are deployed."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "existing_resource_group_name" {
  description = "Existing sandbox resource group into which all lab resources are deployed."
  type        = string
  default     = "1-8eff4f70-playground-sandbox"
}

variable "location" {
  description = "Azure region for the lab."
  type        = string
  default     = "westus"
}

variable "prefix" {
  description = "Short lowercase prefix used in resource names."
  type        = string
  default     = "contoso-lab1"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.prefix))
    error_message = "prefix must contain 3-20 lowercase letters, numbers, or hyphens."
  }
}

variable "admin_username" {
  description = "Local administrator name for the private test VM."
  type        = string
  default     = "azureadmin"
}

variable "enable_management_group" {
  description = "Create the Corp management group, associate this subscription, and assign policy at MG scope. Requires tenant-root permissions."
  type        = bool
  default     = false
}

variable "corp_management_group_id" {
  description = "Stable ID for the optional Corp management group."
  type        = string
  default     = "contoso-corp"
}

variable "deploy_test_vm" {
  description = "Deploy a private Ubuntu VM for route and egress validation."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to resources."
  type        = map(string)
  default     = {}
}
