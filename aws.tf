locals {
  s3_origin_id                  = "S3-${var.s3-bucket}"
  cache_policy_CachingOptimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

variable "aws_region" {
  description = "AWS region"
}

provider "aws" {
  region = var.aws_region
}

variable "s3-bucket" {
  description = "AWS S3 Bucket name"
}

resource "aws_s3_bucket" "bucket" {
  bucket              = var.s3-bucket
  object_lock_enabled = false
}

resource "aws_s3_bucket_policy" "access" {
  bucket = var.s3-bucket
  policy = data.aws_iam_policy_document.s3_access.json
}

resource "aws_cloudfront_origin_access_identity" "cdn" {
  comment = "cdn"
}

resource "aws_s3_bucket_public_access_block" "cdn" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "s3_access" {
  statement {
    actions = ["s3:GetObject"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.cdn.iam_arn]
    }
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
    sid       = "PublicReadForGetBucketObjects"
  }
  statement {
    actions = ["s3:*"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.primary.arn]
    }
    resources = [aws_s3_bucket.bucket.arn, "${aws_s3_bucket.bucket.arn}/*"]
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  aliases         = ["cdn.${var.domain}"]
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
    target_origin_id       = "www.${var.domain}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    smooth_streaming       = false
    cache_policy_id        = local.cache_policy_CachingOptimized
  }
  origin {
    domain_name = "www.${var.domain}"
    origin_id   = "www.${var.domain}"
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
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cdn.cloudfront_access_identity_path
    }
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

resource "aws_sesv2_email_identity" "email" {
  email_identity = var.domain
}

resource "aws_iam_user" "primary" {
  name = "${replace(var.domain, ".", "-")}-primary"
}

resource "aws_iam_access_key" "access_key" {
  user = aws_iam_user.primary.name
}

data "aws_iam_policy_document" "ses_policy_document" {
  statement {
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ses_policy" {
  name   = "${replace(var.domain, ".", "-")}-SES"
  policy = data.aws_iam_policy_document.ses_policy_document.json
}

resource "aws_iam_user_policy_attachment" "user_policy" {
  user       = aws_iam_user.primary.name
  policy_arn = aws_iam_policy.ses_policy.arn
}
