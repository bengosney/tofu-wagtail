provider "heroku" {}

variable "app-name" {
  description = "Heroku App Name"
}

variable "heroku_dyno_qty" {
  description = "Quantity of dynos"
  default     = 1
}

variable "heroku_dyno_size" {
  description = "Size of dynos"
  default     = "Basic"
}

resource "heroku_app" "production" {
  name   = var.app-name
  region = "eu"

  buildpacks = ["heroku/python"]

  sensitive_config_vars = {
    SMTP_PASS               = aws_iam_access_key.access_key.ses_smtp_password_v4
    SMTP_USER               = aws_iam_access_key.access_key.id
    SMTP_PORT               = "587"
    SMTP_HOST               = "email-smtp.${var.aws_region}.amazonaws.com"
    AWS_REGION_NAME         = var.aws_region
    AWS_S3_CUSTOM_DOMAIN    = "cdn.${var.domain}"
    AWS_STORAGE_BUCKET_NAME = var.s3-bucket
    AWS_ACCESS_KEY_ID       = aws_iam_access_key.access_key.id
    AWS_SECRET_ACCESS_KEY   = aws_iam_access_key.access_key.secret
  }
}

resource "heroku_addon" "postgresql" {
  app_id = heroku_app.production.id
  plan   = "heroku-postgresql:mini"
}

resource "heroku_formation" "production" {
  app_id   = heroku_app.production.id
  type     = "web"
  quantity = var.heroku_dyno_qty
  size     = var.heroku_dyno_size
}

resource "heroku_ssl" "production" {
  count             = var.heroku_dyno_size == "Eco" ? 0 : 1
  app_id            = heroku_app.production.uuid
  certificate_chain = cloudflare_origin_ca_certificate.origin_cert.certificate
  private_key       = tls_private_key.origin_cert.private_key_pem
  depends_on        = [heroku_formation.production]
}

resource "heroku_domain" "production" {
  app_id          = heroku_app.production.id
  hostname        = "www.${var.domain}"
  sni_endpoint_id = var.heroku_dyno_size == "Eco" ? null : heroku_ssl.production[0].id
}

output "production_app_url" {
  value = heroku_app.production.web_url
}

output "domain" {
  value = heroku_domain.production.cname
}
