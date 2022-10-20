resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
    comment = "Origin Access for ${var.bucket_name}"
}

resource "aws_cloudfront_distribution" "app_cloudfront_distribution" {
  origin {
    domain_name = aws_s3_bucket.app_s3_bucket.bucket_regional_domain_name
    origin_id   = var.origin_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for the ${var.standard_tags.Project} AppUI project."
  default_root_object = "index.html"

  aliases = ["${var.bucket_name}"]

  custom_error_response {
      error_caching_min_ttl = 60
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.origin_name

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    compress = true
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  price_class = "PriceClass_All"

  viewer_certificate {
    acm_certificate_arn = var.acm_certificate
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }

  web_acl_id = var.enable_geo_restriction ? aws_wafv2_web_acl.app_waf_webacl_allowed_geo[0].arn : null

  tags = {
    Name = "${var.project_prefix}-CLOUDFRONT-AppUI-Distribution"
  }

  custom_error_response {
    error_caching_min_ttl   = 60
    error_code              = 404
    response_code           = 200
    response_page_path      = "/index.html"
  }
}
