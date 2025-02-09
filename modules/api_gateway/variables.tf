variable "aws_region" {
  description = "AWS region where the API Gateway and Lambda are deployed"
  type        = string
  default     = "us-east-1"
}
variable "lambda_function_arn" {
  description = "ARN of the Lambda function"
}
