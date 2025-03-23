locals {

  deploy_environment = {
    "environment"      = "${var.deployment_environment}"
    "team"             = "${var.organisation_id}"
    "application"      = "generic"
    "owner" = "${var.owner}"
    "costcenter"       = "${var.cost_center}"
    "department"       = "${var.cost_center}"
  }
}
