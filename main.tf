terraform {
  required_providers {
    heroku = {
      source  = "heroku/heroku"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "heroku" {}

variable "app-id" {
  description = "Stretch Their Legs website"
  default = "stretchtheirlegs-web"
}

resource "heroku_app" "production" {
  name   = var.app-id
  region = "eu"

  buildpacks = ["heroku/python"]
}

resource "heroku_addon" "postgres" {
  app_id = heroku_app.production.id
  plan = "heroku-postgresql:mini"
}

resource "heroku_build" "production" {
  app_id     = heroku_app.production.id
  buildpacks = ["heroku/python"]

  source {
    url     = "https://github.com/mars/cra-example-app/archive/v2.1.1.tar.gz"
    version = "2.1.1"
  }
}

resource "heroku_formation" "production" {
  app_id     = heroku_app.production.id
  type       = "web"
  quantity   = 1
  size       = "Basic"
  depends_on = [heroku_build.production]
}

output "production_app_url" {
  value = heroku_app.production.web_url
}