output "api_gateway_url" {
  value = aws_api_gateway_deployment.translation_deployment.invoke_url
}
