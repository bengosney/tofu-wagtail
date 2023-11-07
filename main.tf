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
  }

  required_version = ">= 1.2.0"
}

variable "domain" {
  description = "Domain"
}

variable "ssl-id" {
  description = "SSL UID"
}

variable "app-id" {
  description = "Heroku App ID"
}

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

import {
  id = "${heroku_app.production.name}:${var.ssl-id}"
  to = heroku_ssl.production
}

resource "heroku_ssl" "production" {
  app_id = heroku_app.production.uuid
  certificate_chain = cloudflare_origin_ca_certificate.origin_cert.certificate
  private_key = tls_private_key.origin_cert.private_key_pem

  depends_on = [heroku_formation.production]
}

import {
  id = "${heroku_app.production.name}:${var.domain}"
  to = heroku_domain.production
}

resource "heroku_domain" "production" {
  app_id   = heroku_app.production.id
  hostname = var.domain
  sni_endpoint_id = heroku_ssl.production.id
}

output "production_app_url" {
  value = heroku_app.production.web_url
}

output "domain" {
  value = heroku_domain.production.cname  
}


provider "cloudflare" {}

variable "zone-id" {
  description = "Cloudflare zone ID"
}

resource "cloudflare_record" "www" {
  name            = "www"
  proxied         = true
  type            = "CNAME"
  value           = heroku_domain.production.cname
  zone_id         = var.zone-id
}

resource "tls_private_key" "origin_cert" {
  algorithm = "RSA"
}

resource "tls_cert_request" "origin_cert" {
  private_key_pem = tls_private_key.origin_cert.private_key_pem

  subject {
    common_name  = ""
    organization = var.domain
  }
}

resource "cloudflare_origin_ca_certificate" "origin_cert" {
  csr                  = tls_cert_request.origin_cert.cert_request_pem
  hostnames            = [replace(var.domain, "/^www./", "*."), replace(var.domain, "/^www./", "")]
  request_type         = "origin-rsa"
  requested_validity   = 5475
  min_days_for_renewal = 365
}
