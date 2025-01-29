terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.84.0"
    }
  }
}
provider "aws" {
  region  = "us-east-1"
}

resource "aws_s3_bucket" "request_store" {
  bucket = "translation-request-bucket"

  tags = {
    Name        = "translation_request_store"
  }
}

resource "aws_s3_bucket" "response_logs_store" {
  bucket = "response-and-logs-store-bucket"

  tags = {
    Name        = "response_logs_storage"
  }
}

#Create IAM Role for Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name               = "LambdaExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Attach IAM Policy to the Role
resource "aws_iam_policy" "lambda_s3_policy" {
  name   = "LambdaS3AccessPolicy"
  policy = data.aws_iam_policy_document.lambda_s3_access_policy.json
}

data "aws_iam_policy_document" "lambda_s3_access_policy" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.request_store.arn,
      "${aws_s3_bucket.request_store.arn}/*",
      aws_s3_bucket.response_logs_store.arn,
      "${aws_s3_bucket.response_logs_store.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}