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
  id = "${heroku_app.production.name}:${var.domain}"
  to = heroku_domain.production
}

resource "heroku_domain" "production" {
  app_id          = heroku_app.production.id
  hostname        = var.domain
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
  name    = "www"
  proxied = true
  type    = "CNAME"
  value   = heroku_domain.production.cname
  zone_id = var.zone-id
}

resource "cloudflare_record" "cdn" {
  name    = "cdn"
  proxied = true
  type    = "CNAME"
  value   = aws_cloudfront_distribution.cdn.domain_name
  zone_id = var.zone-id
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

resource "cloudflare_page_rule" "non-www-to-www" {
  priority = 1
  status   = "active"
  target   = "${replace(var.domain, "/^www./", "")}/*"
  zone_id  = var.zone-id
  actions {
    forwarding_url {
      status_code = 301
      url         = "https://${var.domain}/$1"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
  alias  = "london"
}

provider "aws" {
  region = "eu-west-1"
  alias  = "ireland"
}

import {
  to       = aws_s3_bucket.bucket
  id       = var.s3-bucket
  provider = aws.london
}

variable "s3-bucket" {
  description = "AWS S3 Bucket name"
}

resource "aws_s3_bucket" "bucket" {
  provider            = aws.london
  bucket              = var.s3-bucket
  object_lock_enabled = false
  tags = {
    project = "stl"
  }
  tags_all = {
    project = "stl"
  }
}

locals {
  s3_origin_id                  = "S3-${var.s3-bucket}"
  cache_policy_CachingOptimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

resource "aws_cloudfront_distribution" "cdn" {
  provider        = aws.london
  aliases         = [replace(var.domain, "/^www./", "cdn.")]
  enabled         = true
  http_version    = "http2"
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    smooth_streaming       = false
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "allow-all"
    cache_policy_id        = local.cache_policy_CachingOptimized
  }
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.domain
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    smooth_streaming       = false
    cache_policy_id        = local.cache_policy_CachingOptimized
  }
  origin {
    domain_name = var.domain
    origin_id   = var.domain
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }
  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn            = "arn:aws:acm:us-east-1:126391784568:certificate/0854b4cf-6cab-4955-8c89-184e3a036a63"
    cloudfront_default_certificate = false
    iam_certificate_id             = null
    minimum_protocol_version       = "TLSv1.2_2019"
    ssl_support_method             = "sni-only"
  }
}

#import {
#  to = aws
#  provider = aws.ireland
#}