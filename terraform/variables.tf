variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_image_uri" {
  description = "ECR image URI for Lambda"
  type        = string
}

variable "frontend_image_uri" {
  description = "ECR image URI for frontend"
  type        = string
}
