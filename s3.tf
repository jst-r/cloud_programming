resource "aws_s3_bucket" "static" {
  bucket = "jstre-iu-cloud-programming-bucket"
}

resource "aws_s3_object" "static_files" {
  bucket       = aws_s3_bucket.static.id

  for_each = fileset("static", "*")

  key          = each.value
  source       = "static/${each.value}"
  content_type = "text/html"
  etag         = filemd5("static/${each.value}")
}


resource "aws_s3_bucket_website_configuration" "s3_website" {
  bucket = aws_s3_bucket.static.id

  depends_on = [ aws_s3_object.static_files ]
  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket              = aws_s3_bucket.static.id
  block_public_acls   = false
  block_public_policy = false
}

resource "aws_s3_bucket_policy" "open_access" {
  bucket = aws_s3_bucket.static.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "Public_access"
    Statement = [
      {
        Sid       = "IPAllow"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.static.arn}/*"
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.static]
}

output "website_url" {
  value = "http://${aws_s3_bucket.static.bucket}.s3-website.${aws_s3_bucket.static.region}.amazonaws.com"
}