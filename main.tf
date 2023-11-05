terraform {
  required_providers {
    heroku = {
      source  = "heroku/heroku"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}

variable "app-id" {
  description = "Heroku App ID"
}

variable "postgresql-id" {
  description = "Postgresql App ID"
}

provider "heroku" {}

import {
  id = var.app-id
  to = heroku_app.production
}

import { 
  id = var.postgresql-id
  to = heroku_addon.postgresql
}

resource "heroku_app" "production" {
  name   = var.app-id
  region = "eu"

  buildpacks = ["heroku/python"]
}

resource "heroku_addon" "postgresql" {
  app_id = heroku_app.production.id
  plan = "heroku-postgresql:mini"
}

import {
  id = "${heroku_app.production.id}:web"
  to = heroku_formation.production
}

resource "heroku_formation" "production" {
  app_id     = heroku_app.production.id
  type       = "web"
  quantity   = 1
  size       = "Basic"
}

output "production_app_url" {
  value = heroku_app.production.web_url
}
