output "api_gateway_url" {
  description = "API Gateway URL"
  value       = aws_api_gateway_rest_api.translation_api.execution_arn
}

output "request_s3_bucket" {
  description = "S3 Bucket for request files"
  value       = aws_s3_bucket.request_store.bucket
}

output "response_s3_bucket" {
  description = "S3 Bucket for translated files"
  value       = aws_s3_bucket.response_store.bucket
}
