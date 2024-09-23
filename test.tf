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
# S3

# Create an S3 bucket
resource "aws_s3_bucket" "static" {
  bucket = "jstre-iu-cloud-programming-bucket"
}

resource "aws_s3_bucket_acl" "s3_acl" {
  bucket = aws_s3_bucket.static.id
  acl = "public-read"
}

# Upload an index.html file to the S3 bucket
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.static.id
  key    = "index.html"
  source = "static/index.html"
  etag   = filemd5("static/index.html")
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "s3_website" {
  bucket = aws_s3_bucket.static.id

  index_document {
    suffix = "index.html"
  }
}

#########################
# API Gateway

resource "aws_api_gateway_rest_api" "api" {
  name        = "example-api"
  description = "Example API to serve S3 and Lambda"
}

# Root resource serving static S3 website
resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = ""
}

resource "aws_api_gateway_method" "root_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.root.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.root.id
  http_method             = aws_api_gateway_method.root_method.http_method
  type                    = "HTTP"
  uri                     = aws_s3_bucket_website_configuration.s3_website.website_domain
  integration_http_method = "GET"
}

# /api/increment_counter resource
resource "aws_api_gateway_resource" "api_increment_counter" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "api/increment_counter"
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.api_increment_counter.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.api_increment_counter.id
  http_method             = aws_api_gateway_method.post_method.http_method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.example_lambda.invoke_arn
  integration_http_method = "POST"
}

# Grant API Gateway permissions to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${aws_api_gateway_rest_api.api.execution_arn}:${aws_api_gateway_rest_api.api.id}/*/POST/api/increment_counter"
}

#########################
# Outputs

# output "api_endpoint" {
#   value = aws_api_gateway_rest_api.api.
# }
