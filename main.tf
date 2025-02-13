terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ----------------------------
# 1. CREATE S3 BUCKETS
# ----------------------------
resource "aws_s3_bucket" "request_store" {
  bucket = "translation-request-bucket"

  tags = {
    Name = "Translation Request Storage"
  }
}

resource "aws_s3_bucket" "response_store" {
  bucket = "translation-response-bucket"

  tags = {
    Name = "Translation Response Storage"
  }
}

# ----------------------------
# 1. IAM ROLE FOR LAMBDA
# ----------------------------
resource "aws_iam_role" "lambda_role" {
  name = "translation_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# IAM POLICY FOR LAMBDA ACCESS
resource "aws_iam_policy" "lambda_s3_policy" {
  name   = "LambdaS3AccessPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = [
          "${aws_s3_bucket.request_store.arn}/*",
          "${aws_s3_bucket.response_store.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [
          aws_s3_bucket.request_store.arn,
          aws_s3_bucket.response_store.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = "translate:TranslateText"
        Resource = "*"
      }
    ]
  })
}

# ATTACH POLICY TO LAMBDA ROLE
resource "aws_iam_role_policy_attachment" "lambda_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

# ----------------------------
# 2. AWS LAMBDA FUNCTION (ZIP PACKAGE)
# ----------------------------
resource "aws_lambda_function" "translation_lambda" {
  function_name = "TranslationProcessor"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  filename      = "lambda_function.zip"
  timeout       = 10
  memory_size   = 512

  environment {
    variables = {
      REQUEST_BUCKET  = aws_s3_bucket.request_store.bucket
      RESPONSE_BUCKET = aws_s3_bucket.response_store.bucket
    }
  }
}

# ✅ FIX: ADD MISSING LAMBDA PERMISSION
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translation_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.translation_api.execution_arn}/*/*"
}

# ----------------------------
# 3. API GATEWAY TO TRIGGER LAMBDA
# ----------------------------
resource "aws_api_gateway_rest_api" "translation_api" {
  name        = "TranslationAPI"
  description = "API for text translation"
}

resource "aws_api_gateway_resource" "translate_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_rest_api.translation_api.root_resource_id
  path_part   = "translate"
}

resource "aws_api_gateway_method" "translate_post" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.translate_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.translation_api.id
  resource_id             = aws_api_gateway_resource.translate_resource.id
  http_method             = aws_api_gateway_method.translate_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.translation_lambda.invoke_arn
}

# ✅ CORS CONFIGURATION
resource "aws_api_gateway_method" "cors_options" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.translate_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_integration" {
  rest_api_id             = aws_api_gateway_rest_api.translation_api.id
  resource_id             = aws_api_gateway_resource.translate_resource.id
  http_method             = aws_api_gateway_method.cors_options.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = <<EOT
{
  "statusCode": 200
}
EOT
  }
}

resource "aws_api_gateway_method_response" "cors_method_response" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.translate_resource.id
  http_method = aws_api_gateway_method.cors_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_integration_response" "cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.translate_resource.id
  http_method = aws_api_gateway_method.cors_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type, Authorization'"
  }

  depends_on = [aws_api_gateway_integration.cors_integration]
}

# ✅ DEPLOYMENT
resource "aws_api_gateway_deployment" "translation_deployment" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  depends_on  = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.cors_integration
  ]
}

resource "aws_api_gateway_stage" "translation_stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  deployment_id = aws_api_gateway_deployment.translation_deployment.id
}

# ----------------------------
# 4. OUTPUTS
# ----------------------------
output "api_gateway_url" {
  description = "API Gateway Invoke URL"
  value       = "https://${aws_api_gateway_rest_api.translation_api.id}.execute-api.us-east-1.amazonaws.com/prod"
}


output "request_s3_bucket" {
  description = "S3 Bucket for storing translation requests"
  value       = aws_s3_bucket.request_store.bucket
}

output "response_s3_bucket" {
  description = "S3 Bucket for storing translation responses"
  value       = aws_s3_bucket.response_store.bucket
}