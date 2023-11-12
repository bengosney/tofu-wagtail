
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
    organization = "www.${var.domain}"
  }
}

resource "cloudflare_origin_ca_certificate" "origin_cert" {
  csr                  = tls_cert_request.origin_cert.cert_request_pem
  hostnames            = ["*.${var.domain}", var.domain]
  request_type         = "origin-rsa"
  requested_validity   = 5475
  min_days_for_renewal = 365
}

resource "cloudflare_page_rule" "non-www-to-www" {
  priority = 1
  status   = "active"
  target   = "${var.domain}/*"
  zone_id  = var.zone-id
  actions {
    forwarding_url {
      status_code = 301
      url         = "https://www.${var.domain}/$1"
    }
  }
}

resource "cloudflare_record" "cname_dkim" {
  for_each = toset(aws_sesv2_email_identity.email.dkim_signing_attributes[0].tokens)

  zone_id = var.zone-id
  name    = "${each.value}._domainkey.${var.domain}"
  value   = "${each.value}.dkim.amazonses.com"
  type    = "CNAME"
  proxied = false
}