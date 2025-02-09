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
resource "aws_iam_policy" "lambda_policy" {
  name   = "LambdaTranslatePolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "translate:TranslateText"
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translation_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.translation_api.execution_arn}/*/*"
}



# ATTACH POLICY TO LAMBDA ROLE
resource "aws_iam_role_policy_attachment" "lambda_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ----------------------------
# 2. AWS LAMBDA FUNCTION (ZIP PACKAGE)
# ----------------------------
resource "aws_lambda_function" "translation_lambda" {
  function_name = "TranslationProcessor"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"  # ✅ Now using a standard Python runtime
  handler       = "lambda_function.lambda_handler"
  filename      = "lambda_function.zip"  # ✅ Lambda function packaged as a ZIP file

  timeout       = 10
  memory_size   = 512
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

resource "aws_api_gateway_deployment" "translation_deployment" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  depends_on  = [aws_api_gateway_integration.lambda_integration]
}

resource "aws_api_gateway_stage" "translation_stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  deployment_id = aws_api_gateway_deployment.translation_deployment.id
}



# ----------------------------
# IAM ROLE FOR ECS TASK EXECUTION
# ----------------------------
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecsExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach AWS Managed Policy to Allow ECS to Pull Images from ECR
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# ----------------------------
# 4. DEPLOY FRONTEND WITH ECS (FARGATE)
# ----------------------------
resource "aws_ecs_cluster" "frontend_cluster" {
  name = "translation-frontend-cluster"
}

resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "translation-frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "translation-frontend"
      image     = "654654366333.dkr.ecr.us-east-1.amazonaws.com/translation-frontend:latest"  # Replace with your ECR URI
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "frontend_service" {
  name            = "translation-frontend-service"
  cluster         = aws_ecs_cluster.frontend_cluster.id
  task_definition = aws_ecs_task_definition.frontend_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = ["subnet-04f67b02f05b456fa", "subnet-0d5deb68e3a796372"]  # Replace with actual subnet IDs
    security_groups = ["sg-07b24e3a119273641"]  # Replace with actual security group ID
    assign_public_ip = true
  }
}

# ----------------------------
# 5. OUTPUTS (PRINT USEFUL INFO)
# ----------------------------
output "api_gateway_url" {
  description = "API Gateway Invoke URL"
  value       = "https://${aws_api_gateway_rest_api.translation_api.id}.execute-api.us-east-1.amazonaws.com/prod"
}
