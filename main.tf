provider "aws" {
  region = var.region # Frankfurt
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

output "deployment_url" {
  description = "URL that users will visit"
  value       = aws_cloudfront_distribution.cloudfront.domain_name
}

output "gateway_url" {
  description = "URL to hit API gateway directly (should only be used for troubleshooting the deployment)"
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "s3_website_url" {
  description = "URL to the S3 website (should only be used for troubleshooting the deployment)"
  value = "http://${aws_s3_bucket.static.bucket}.s3-website.${aws_s3_bucket.static.region}.amazonaws.com"
}