terraform {
  required_providers {
    heroku = {
      source  = "heroku/heroku"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.23.1"
    }
  }
  required_version = ">= 1.2.0"
}

variable "domain" {
  description = "Domain (no www)"
}
