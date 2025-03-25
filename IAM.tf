resource "aws_iam_role" "ecs_task_execution_role" {
  name = "my-ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy" {
  name       = "ecsTaskExecutionRolePolicyAttachment"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ecs_exec_policy" {
  name        = "ecs-exec-policy"
  description = "Policy required for using ECS Exec with SSM"
  policy      = jsonencode({
    Version   : "2012-10-17",
    Statement : [
      {
        Effect   : "Allow",
        Action   : [
          "ecs:ExecuteCommand"
        ],
        Resource : "*"
      },
      {
        Effect   : "Allow",
        Action   : [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ecs_exec_policy_attachment" {
  name       = "ecsExecPolicyAttachment"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = aws_iam_policy.ecs_exec_policy.arn
}
