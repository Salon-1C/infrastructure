data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for repo in var.github_repos : "repo:${var.github_org}/${repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "${var.project}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
  tags               = { Project = var.project }
}

data "aws_iam_policy_document" "github_deploy_policy" {
  statement {
    sid    = "ECRAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [
      for name in var.ecr_repository_names :
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${name}"
    ]
  }

  statement {
    sid    = "ECSRedeploy"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeClusters",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_deploy" {
  name   = "${var.project}-github-deploy-policy"
  policy = data.aws_iam_policy_document.github_deploy_policy.json
}

resource "aws_iam_role_policy_attachment" "github_deploy" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = aws_iam_policy.github_deploy.arn
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = var.project }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_execution_secrets" {
  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project}/*",
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project}-*/*",
    ]
  }
}

resource "aws_iam_policy" "ecs_execution_secrets" {
  name   = "${var.project}-ecs-execution-secrets"
  policy = data.aws_iam_policy_document.ecs_execution_secrets.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_secrets" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_execution_secrets.arn
}

resource "aws_iam_role" "business_logic_task" {
  name = "${var.project}-business-logic-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = var.project }
}

resource "aws_iam_role" "stream_engine_task" {
  name = "${var.project}-stream-engine-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = var.project }
}

resource "aws_iam_role" "record_service_task" {
  name = "${var.project}-record-service-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = var.project }
}

resource "aws_iam_role" "activities_task" {
  name = "${var.project}-activities-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = var.project }
}

resource "aws_iam_role" "recommendations_task" {
  name = "${var.project}-recommendations-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = var.project }
}

resource "aws_iam_role" "frontend_task" {
  name = "${var.project}-frontend-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = var.project }
}

data "aws_iam_policy_document" "record_service_s3" {
  statement {
    sid    = "RecordingsBucketRW"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      var.recordings_bucket_arn,
      "${var.recordings_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_policy" "record_service_s3" {
  name   = "${var.project}-record-service-s3"
  policy = data.aws_iam_policy_document.record_service_s3.json
}

resource "aws_iam_role_policy_attachment" "record_service_s3" {
  role       = aws_iam_role.record_service_task.name
  policy_arn = aws_iam_policy.record_service_s3.arn
}
