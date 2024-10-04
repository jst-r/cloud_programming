locals {
  s3_origin_id = "s3_origin"
  api_origin_id = "api_origin"
}

resource "aws_cloudfront_distribution" "cloudfront" {
  origin {
    domain_name              = "${aws_s3_bucket.static.bucket}.s3-website.${aws_s3_bucket.static.region}.amazonaws.com"
    origin_id                = local.s3_origin_id
    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port = 80
      https_port = 443 # afaik doesn't do anything
      origin_ssl_protocols = [ "SSLv3" ]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true

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
  }

  # Cache behavior with precedence 0
#   ordered_cache_behavior {
#     path_pattern     = "/content/immutable/*"
#     allowed_methods  = ["GET", "HEAD", "OPTIONS"]
#     cached_methods   = ["GET", "HEAD", "OPTIONS"]
#     target_origin_id = local.s3_origin_id

#     forwarded_values {
#       query_string = false
#       headers      = ["Origin"]

#       cookies {
#         forward = "none"
#       }
#     }

#     min_ttl                = 0
#     default_ttl            = 86400
#     max_ttl                = 31536000
#     compress               = true
#     viewer_protocol_policy = "redirect-to-https"
#   }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cloudfront_endpoint" {
    value = aws_cloudfront_distribution.cloudfront.domain_name
}