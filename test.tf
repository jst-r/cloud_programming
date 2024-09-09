provider "aws" {
  region = var.region # Frankfurt
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

#########################
# Lambda

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/index.js"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "example_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  function_name = "example-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
}

resource "aws_iam_role" "lambda_role" {
  name = "example-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

#########################
# Api gateway

resource "aws_api_gateway_rest_api" "api" {
  name        = "my_api"
  description = "API Gateway for Lambda"
}

resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "lambda"
}

resource "aws_api_gateway_method" "api_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.api_resource.id
  http_method             = aws_api_gateway_method.api_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.example_lambda.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
  ]
}

output "api_endpoint" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_deployment.api_deployment.stage_name}/lambda"
}

#########################
# S3

# Create an S3 bucket
resource "aws_s3_bucket" "static_website" {
  bucket = "jstre-iu-cloud-programming-bucket"
}

resource "aws_s3_bucket_acl" "static_website_acl" {
  bucket = aws_s3_bucket.static_website.id
  acl    = "private"
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.static_website.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Upload an index.html file to the S3 bucket
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.static_website.id
  key    = "index.html"
  source = "static/index.html"
  etag   = filemd5("static/index.html")
}

locals {
  s3_origin_id = "static_s3_origin_id"
}


# Create a CloudFront distribution
resource "aws_cloudfront_distribution" "static_website_distribution" {

  origin {
    domain_name              = aws_s3_bucket.static_website.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
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

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cloudfront_distribution_url" {
  value = "https://${aws_cloudfront_distribution.static_website_distribution.domain_name}"
}