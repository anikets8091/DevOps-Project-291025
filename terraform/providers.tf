provider "aws" {
  region = var.region
}

locals {
  name_prefix = var.project_prefix
}
