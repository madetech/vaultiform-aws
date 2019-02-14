provider "aws" {
  version = "~> 1.58"
}

locals {
  default_tags = {
    application = "vault"
    environment = "${var.environment}"
  }

  default_name = "vault-${var.environment}"
}
