# IAM Role for Lambda
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

# IAM Policy for Lambda to access S3 and AWS Translate
resource "aws_iam_policy" "lambda_policy" {
  name   = "LambdaS3TranslatePolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["s3:GetObject", "s3:PutObject"]
      Effect = "Allow"
      Resource = [
        aws_s3_bucket.request_store.arn,
        "${aws_s3_bucket.request_store.arn}/*",
        aws_s3_bucket.response_store.arn,
        "${aws_s3_bucket.response_store.arn}/*"
      ]
    },
    {
      Action = "translate:TranslateText"
      Effect = "Allow"
      Resource = "*"
    }]
  })
}

# Attach Policy to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}
