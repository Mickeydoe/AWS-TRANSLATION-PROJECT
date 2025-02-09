resource "aws_lambda_function" "translation_lambda" {
  function_name = "TranslationProcessor"
  role          = aws_iam_role.lambda_role.arn

  package_type  = "Image"  
  image_uri     = var.lambda_image_uri  

  timeout       = 10
  memory_size   = 512

  environment {
    variables = {
      REQUEST_BUCKET  = aws_s3_bucket.request_store.bucket
      RESPONSE_BUCKET = aws_s3_bucket.response_store.bucket
    }
  }
}
