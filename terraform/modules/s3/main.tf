resource "aws_s3_bucket" "request_store" {
  bucket = "translation-request-bucket"
}

resource "aws_s3_bucket" "response_store" {
  bucket = "translation-response-bucket"
}
