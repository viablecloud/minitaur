variable "cost_center" {
  type        = string
  description = "cost center department or code for the application"
  default = "acme"
}

variable "owner" {
  type        = string
  description = "owner of the application"
  default = "owner@acme.com"
}

variable "deployment_environment" {
  type        = string
  description = "Environment for this Deployment. Not the Environment Domain"
}

variable "primary_location" {
  type        = string
  description = "Longer name of Azure primary region for this deployment"
}

variable "location_short" {
  type        = string
  description = "Abbreviation of this Azure region"
}

variable "organisation_id" {
  type        = string
  description = "short abbreviated code for this organisation or business unit"
  default = "acme"
}

variable "tenant_id" {
  type       = string
  description = "the home tenant ID"
}

variable "management_subscription_id" {
  type       = string
  description = "The Azure Management Subscription used to manage resources in this subscription (or just this current subscription)"
}
