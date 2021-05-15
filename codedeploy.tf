#=== IAM for CodeDeploy =======================================================
data "aws_iam_policy_document" "codedeploy_assumerole" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "ecs-pipeline-deploy"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assumerole.json
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.id
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

#=== CodeDeploy ===============================================================
resource "aws_codedeploy_app" "main" {
  compute_platform = "ECS"
  name             = "my-server"
}

resource "aws_codedeploy_deployment_group" "main" {
  deployment_group_name  = "my-server"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  app_name               = aws_codedeploy_app.main.name
  service_role_arn       = aws_iam_role.codedeploy.arn

  auto_rollback_configuration {
    enabled = true
    events  = [
      "DEPLOYMENT_FAILURE"
    ]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 1
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.my_server.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [
          aws_lb_listener.main.arn
        ]
      }
      target_group {
        name = aws_lb_target_group.my_server_blue.name
      }
      target_group {
        name = aws_lb_target_group.my_server_green.name
      }
    }
  }
}