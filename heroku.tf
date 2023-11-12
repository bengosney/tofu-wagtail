provider "heroku" {}

import {
  id = var.app-id
  to = heroku_app.production
}

resource "heroku_app" "production" {
  name   = var.app-id
  region = "eu"

  buildpacks = ["heroku/python"]
}

resource "heroku_addon" "postgresql" {
  app_id = heroku_app.production.id
  plan   = "heroku-postgresql:mini"
}

import {
  id = "${heroku_app.production.id}:web"
  to = heroku_formation.production
}

resource "heroku_formation" "production" {
  app_id   = heroku_app.production.id
  type     = "web"
  quantity = 1
  size     = "Basic"
}

resource "heroku_ssl" "production" {
  app_id            = heroku_app.production.uuid
  certificate_chain = cloudflare_origin_ca_certificate.origin_cert.certificate
  private_key       = tls_private_key.origin_cert.private_key_pem

  depends_on = [heroku_formation.production]
}

import {
  id = "${heroku_app.production.name}:www.${var.domain}"
  to = heroku_domain.production
}

resource "heroku_domain" "production" {
  app_id          = heroku_app.production.id
  hostname        = "www.${var.domain}"
  sni_endpoint_id = heroku_ssl.production.id
}

output "production_app_url" {
  value = heroku_app.production.web_url
}

output "domain" {
  value = heroku_domain.production.cname
}
