# Primary S3 Bucket (Name must be globally unique across AWS)
resource "aws_s3_bucket" "primary" {
  bucket = "samuelojo-portfolio-primary-2026"
}

# Existing hosted zone and ACM certificate (created outside Terraform)
data "aws_route53_zone" "main" {
  name         = var.domain
  private_zone = false
}

data "aws_acm_certificate" "site" {
  provider    = aws.us_east_1
  domain      = var.domain
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "primary_block" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-portfolio-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Clean URLs: serves folder/index.html for /folder/ and redirects old .html addresses
resource "aws_cloudfront_function" "clean_urls" {
  name    = "portfolio-clean-urls"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file("${path.module}/clean-urls.js")
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  default_root_object = "index.html"

  # Custom domain. Must stay in sync with the certificate below, or a
  # terraform apply will detach samuelojo.tech from the distribution.
  aliases = [var.domain, "www.${var.domain}"]

  origin {
    domain_name              = aws_s3_bucket.primary.bucket_regional_domain_name
    origin_id                = "S3-Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-Origin"
    viewer_protocol_policy = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.clean_urls.arn
    }

    compress = true

    # Managed policies: CachingOptimized and SecurityHeadersPolicy
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  }

  # Unknown paths fall back to the home page (S3 returns 403 via OAC)
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/index.html"
    error_caching_min_ttl = 60
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # ACM certificate (CloudFront certificates live in us-east-1), looked up above
  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.site.arn
    ssl_support_method  = "sni-only"
    # The live setting is TLSv1.3_2025 (set in the console). This AWS provider
    # version doesn't accept that value yet, so a valid placeholder goes here and
    # lifecycle.ignore_changes below stops Terraform from downgrading it.
    minimum_protocol_version = "TLSv1.2_2021"
  }

  lifecycle {
    ignore_changes = [viewer_certificate[0].minimum_protocol_version]
  }
}

resource "aws_s3_bucket_policy" "cloudfront_read" {
  bucket = aws_s3_bucket.primary.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontOAC"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.primary.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

output "aws_cloudfront_domain" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "aws_cloudfront_id" {
  value = aws_cloudfront_distribution.cdn.id
}