terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.84.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------------
# 1. CREATE S3 BUCKETS
# ---------------------------------
resource "aws_s3_bucket" "request_store" {
  bucket = "translation-request-bucket"

  tags = {
    Name = "translation_request_store"
  }
}

resource "aws_s3_bucket" "response_logs_store" {
  bucket = "response-and-logs-store-bucket"

  tags = {
    Name = "response_logs_storage"
  }
}

# ---------------------------------
# 2. CREATE IAM ROLE FOR LAMBDA
# ---------------------------------
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

# Attach IAM Policy to allow Lambda to access S3 and Translate
resource "aws_iam_policy" "lambda_s3_translate_policy" {
  name   = "LambdaS3TranslateAccessPolicy"
  policy = data.aws_iam_policy_document.lambda_s3_translate_access_policy.json
}

data "aws_iam_policy_document" "lambda_s3_translate_access_policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.request_store.arn,
      "${aws_s3_bucket.request_store.arn}/*",
      aws_s3_bucket.response_logs_store.arn,
      "${aws_s3_bucket.response_logs_store.arn}/*"
    ]
  }

  statement {
    actions = [
      "translate:TranslateText"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "lambda_logging_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name   = "LambdaLoggingPolicy"
  policy = data.aws_iam_policy_document.lambda_logging_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_logging_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_s3_translate_policy.arn
}

# ---------------------------------
# 3. CREATE AWS LAMBDA FUNCTION
# ---------------------------------
resource "aws_lambda_function" "translation_lambda" {
  function_name    = "TranslationProcessor"
  runtime         = "python3.9"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "lambda_function.lambda_handler"
  filename        = "lambda_function.zip"

  environment {
    variables = {
      REQUEST_BUCKET  = aws_s3_bucket.request_store.bucket
      RESPONSE_BUCKET = aws_s3_bucket.response_logs_store.bucket
    }
  }
}

# ---------------------------------
# LINK API GATEWAY FILE
# ---------------------------------
module "api_gateway" {
  source = "./modules/api_gateway"  # Reference the API Gateway file
  lambda_function_arn = aws_lambda_function.translation_lambda.arn
}
