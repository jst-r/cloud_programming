locals {
  s3_origin_id  = "s3_origin"
  api_origin_id = "api_origin"
}

resource "aws_cloudfront_distribution" "cloudfront" {
  origin {
    domain_name = "${aws_s3_bucket.static.bucket}.s3-website.${var.region}.amazonaws.com"
    origin_id   = local.s3_origin_id

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = 80
      https_port             = 443 # afaik doesn't do anything
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = "${aws_apigatewayv2_api.lambda.id}.execute-api.${var.region}.amazonaws.com"
    origin_path = "/${aws_apigatewayv2_stage.default.name}" # $default stage would probably break it
    origin_id   = local.api_origin_id

    custom_origin_config {
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      http_port              = 80
      https_port             = 443
    }
  }

  enabled         = true
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    compress = true
  }

  ordered_cache_behavior {
    path_pattern = "/api/*"

    allowed_methods  = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.api_origin_id

    forwarded_values {
      query_string = false

      headers = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
