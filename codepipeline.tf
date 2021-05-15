#=== Artifact Bucket ==========================================================
data "aws_s3_bucket" "pipeline_artifact" {
  bucket = "kou164nkn-artifact-bucket"
}

#=== IAM for Codepipeline =====================================================
data "aws_iam_policy_document" "codepipeline_assumerole" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "ecs-pipeline-project"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assumerole.json
}

resource "aws_iam_policy" "codepipeline" {
  name        = "ecs-pipeline-codepipeline"
  description = "ecs-pipeline-codepipeline"

  policy = jsonencode(
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "*",
            "Effect": "Allow",
            "Condition": {
                "StringEqualsIfExists": {
                    "iam:PassedToService": [
                        "cloudformation.amazonaws.com",
                        "elasticbeanstalk.amazonaws.com",
                        "ec2.amazonaws.com",
                        "ecs-tasks.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Sid": "S3Policy",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplication",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:RegisterApplicationRevision"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "elasticloadbalancing:*",
                "cloudwatch:*",
                "sns:*",
                "ecs:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "lambda:InvokeFunction",
                "lambda:ListFunctions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Effect": "Allow",
            "Action": [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "ecr:DescribeImages"
            ],
            "Resource": "*"
        }
    ]
})
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.id
  policy_arn = aws_iam_policy.codepipeline.arn
}


#=== CodePipeline =============================================================
resource "aws_codepipeline" "main" {
  name     = "ecs-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    type     = "S3"
    location = data.aws_s3_bucket.pipeline_artifact.id
  }

  stage {
    name = "Source"

    action {
      name             = "ImgSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      run_order        = 1
      output_artifacts = ["ImgSrc"]

      configuration = {
        S3Bucket             = "kou164nkn-imagedetail-bucket"
        S3ObjectKey          = "my_service/imageDetail.json.zip"
        PollForSourceChanges = true
      }
    }

    action {
      name             = "DefSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      run_order        = 1
      output_artifacts = ["SpecSrc"]

      configuration = {
        S3Bucket             = "kou164nkn-source-bucket"
        S3ObjectKey          = "my_server.zip"
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "Approval"

    action {
      name      = "ConfirmToDeploy"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
      version   = "1"
      run_order = 2
    }
  }

  /*
  stage {
    name = "EnabledWafBlock"

    action {
      name      = "InvokeLambda"
      category  = "Invoke"
      owner     = "AWS"
      provider  = "Lambda"
      version   = "1"
      run_order = 3

      configuration = {
        FunctionName   = var.waf_lambda_name
        UserParameters = "INSERT"
      }
    }
  }
  */

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      run_order       = 4
      input_artifacts = ["ImgSrc", "SpecSrc"]

      configuration = {
        ApplicationName                = aws_codedeploy_app.main.name
        DeploymentGroupName            = "my-server"
        TaskDefinitionTemplateArtifact = "SpecSrc"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "SpecSrc"
        AppSpecTemplatePath            = "appspec.yaml"
        Image1ArtifactName             = "ImgSrc"
        Image1ContainerName            = "IMAGE1_NAME"
      }
    }
  }

  /*
  stage {
    name = "DisabledWafBlock"

    action {
      name      = "InvokeLambda"
      category  = "Invoke"
      owner     = "AWS"
      provider  = "Lambda"
      version   = "1"
      run_order = 5

      configuration = {
        FunctionName   = var.waf_lambda_name
        UserParameters = "DELETE"
      }
    }
  }
  */
}
