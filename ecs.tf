# === ECS Cluster =======================================
resource "aws_ecs_cluster" "main" {
  name = "ecs-bg_cluster"
}
# =======================================================


# === IAM for Task Role =================================
resource "aws_iam_role" "task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
})
}

resource "aws_iam_role_policy" "task_role" {
  name = "ecsTaskExecuteCommandRolePolicy"
  role = aws_iam_role.task_role.id

  policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    }
  ]
})
}
# =======================================================


# === IAM for executing task ============================
data "aws_iam_role" "official-ecs-exec" {
  name = "ecsTaskExecutionRole"
}

resource "aws_iam_role" "ecs-exec" {
  name = "ecsExecutionRoleForEcsDeploy"

  assume_role_policy = jsonencode(
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
            "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
})
}

resource "aws_iam_role_policy" "ecs-exec" {
  name = "amazonEcsExecutionRolePolicyForEcsDeploy"
  role = aws_iam_role.ecs-exec.id

  policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
})
}
# =======================================================


# === SecurityGroup for ECS Service =====================
resource "aws_security_group" "ecs-deploy" {
  name        = "allow_inbound_to_ecs"
  description = "Allow inbound traffic to ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [ aws_vpc.main.cidr_block ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# =======================================================


# === ECS Service =======================================
resource "aws_cloudwatch_log_group" "my_server" {
  name = "/aws/ecs/my-server"
}

resource "aws_ecs_service" "my_server" {
  name            = "my_server"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.my_server.arn

  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  propagate_tags   = "TASK_DEFINITION"

  enable_execute_command = true

  health_check_grace_period_seconds = 20

  load_balancer {
    target_group_arn = aws_lb_target_group.my_server_blue.arn
    container_name   = "my_server"
    container_port   = 8080
  }

  network_configuration {
    subnets = aws_subnet.private-subnet[*].id

    security_groups = [ aws_security_group.ecs-deploy.id ]
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  depends_on = [ aws_lb_listener.main ]
}


resource "aws_ecs_task_definition" "my_server" {
  family                   = "my_server"
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
  cpu          = "256"
  memory       = "512"

  task_role_arn      = aws_iam_role.task_role.arn
  execution_role_arn = data.aws_iam_role.official-ecs-exec.arn

  container_definitions = jsonencode(
[
  {
    "name": "my_server",
    "image": "${data.aws_caller_identity.self.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/fortune_server:0.1.0",
    "essential": true,
    "cpu": 100,
    "memory": 512,
    "memoryReservation": 256,
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080,
        "protocol": "tcp"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/aws/ecs/my-server",
        "awslogs-region": "ap-northeast-1",
        "awslogs-stream-prefix": "my-server"
      }
    }
  }
])
}
# =======================================================
