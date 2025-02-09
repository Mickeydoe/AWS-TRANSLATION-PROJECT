resource "aws_ecs_cluster" "frontend_cluster" {
  name = "translation-frontend-cluster"
}

resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "translation-frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "translation-frontend"
      image     = var.frontend_image_uri
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
    subnets         = aws_subnet.public_subnets[*].id
    security_groups = [aws_security_group.frontend_sg.id]
    assign_public_ip = true
  }
}
