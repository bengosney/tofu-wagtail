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

variable "stretchtheirlegs" {
  description = "Stretch Their Legs website"
  default = "stretchtheirlegs-web"
}

resource "heroku_app" "stretchtheirlegs" {
  name   = var.stretchtheirlegs
  region = "europe"
}

resource "heroku_addon" "postgres" {
  app_id = heroku_app.stretchtheirlegs.id
  plan = "heroku-postgresql:hobby-dev"
}

resource "heroku_build" "stretchtheirlegs" {
  app_id     = heroku_app.stretchtheirlegs.id
  buildpacks = ["https://github.com/mars/create-react-app-buildpack.git"]

  source {
    url     = "https://github.com/mars/cra-example-app/archive/v2.1.1.tar.gz"
    version = "2.1.1"
  }
}

resource "heroku_formation" "stretchtheirlegs" {
  app_id     = heroku_app.stretchtheirlegs.id
  type       = "web"
  quantity   = 1
  size       = "Basic"
  depends_on = [heroku_build.stretchtheirlegs]
}

output "stretchtheirlegs_app_url" {
  value = heroku_app.stretchtheirlegs.web_url
}