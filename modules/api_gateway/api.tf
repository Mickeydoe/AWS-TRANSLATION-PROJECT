# ---------------------------------
# CREATE API GATEWAY
# ---------------------------------
resource "aws_api_gateway_rest_api" "translation_api" {
  name        = "TranslationAPI"
  description = "API for text translation"
}

# Create /translate resource
resource "aws_api_gateway_resource" "translate_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_rest_api.translation_api.root_resource_id
  path_part   = "translate"
}

# Create HTTP POST method
resource "aws_api_gateway_method" "translate_post" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.translate_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integrate API Gateway with Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.translation_api.id
  resource_id             = aws_api_gateway_resource.translate_resource.id
  http_method             = aws_api_gateway_method.translate_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                   = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.lambda_function_arn}/invocations"

}

resource "aws_api_gateway_deployment" "translation_deployment" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  depends_on  = [aws_api_gateway_integration.lambda_integration]
}

# ✅ NEW: Define API Gateway Stage separately
resource "aws_api_gateway_stage" "translation_stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  deployment_id = aws_api_gateway_deployment.translation_deployment.id
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.translation_api.execution_arn}/*/*"
}
