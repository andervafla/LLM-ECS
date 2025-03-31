
terraform {
  backend "s3" {
    bucket = "tfstate23545345"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Main VPC"
  }
}

locals {
  public_subnets = {
    public_subnet_1 = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "us-east-1a"
    }
    public_subnet_2 = {
      cidr_block        = "10.0.2.0/24"
      availability_zone = "us-east-1b"
    }
  }

  private_subnets = {
    private_subnet_1 = {
      cidr_block        = "10.0.3.0/24"
      availability_zone = "us-east-1a"
    }
    private_subnet_2 = {
      cidr_block        = "10.0.4.0/24"
      availability_zone = "us-east-1b"
    }
  }

  rds_subnets = {
    private_subnet_rds_1 = {
      cidr_block        = "10.0.5.0/24"
      availability_zone = "us-east-1a"
    }
    private_subnet_rds_2 = {
      cidr_block        = "10.0.6.0/24"
      availability_zone = "us-east-1b"
    }
  }

  nat_gateways = {
    nat_gw_a = {
      az                = "us-east-1a"
      public_subnet_key = "public_subnet_1"
    }
    nat_gw_b = {
      az                = "us-east-1b"
      public_subnet_key = "public_subnet_2"
    }
  }
}

resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet ${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each          = local.private_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = "Private Subnet ${each.key}"
  }
}

resource "aws_subnet" "rds" {
  for_each          = local.rds_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = "RDS Subnet ${each.key}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main IGW"
  }
}

resource "aws_eip" "nat" {
  for_each = local.nat_gateways
  domain   = "vpc"

  tags = {
    Name = "NAT EIP ${each.key}"
  }
}

resource "aws_nat_gateway" "main" {
  for_each      = local.nat_gateways
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.value.public_subnet_key].id

  tags = {
    Name = "Main NAT Gateway ${each.key}"
  }
}

resource "aws_route_table" "public" {
  for_each = local.public_subnets

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Public RT ${each.key}"
  }
}

resource "aws_route_table_association" "public_association" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[each.key].id
}


resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = lookup(
      {
        "us-east-1a" = aws_nat_gateway.main["nat_gw_a"].id
        "us-east-1b" = aws_nat_gateway.main["nat_gw_b"].id
      },
      each.value.availability_zone
    )
  }

  tags = {
    Name = "Private RT ${each.key}"
  }
}

resource "aws_route_table_association" "private_association" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}


resource "aws_route_table" "rds" {
  for_each = local.rds_subnets

  vpc_id = aws_vpc.main.id
  tags = {
    Name = "RDS RT ${each.key}"
  }
}

resource "aws_route_table_association" "rds_association" {
  for_each       = aws_subnet.rds
  subnet_id      = each.value.id
  route_table_id = aws_route_table.rds[each.key].id
}

resource "aws_db_subnet_group" "this" {
  name        = "rds-subnet-group"
  subnet_ids  = values(aws_subnet.rds)[*].id
  description = "Subnet group for RDS"

  tags = {
    Name = "RDS Subnet Group"
  }
}


resource "aws_cloudwatch_log_group" "openwebui_log_group" {
  name              = "/ecs/openwebui-service"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "ollama_log_group" {
  name              = "/ecs/ollama-service"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "main" {
  name = "ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_service_discovery_http_namespace" "service_namespace" {
  name        = "internal"
  description = "HTTP namespace for internal services"
}

resource "aws_ecs_task_definition" "ollama_task" {
  family                   = "ollama-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"        
  memory                   = "2048"         
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      "name": "ollama",
      "image": var.ollama_image,
      "essential": true,
      "portMappings": [
        {
          "name": "ollama-port",
          "containerPort": 11434,
          "hostPort": 11434,           
          "protocol": "tcp",
          "appProtocol": "http"       
        }
      ],
      "environment": [
        {
          "name": "OLLAMA_HOST",
          "value": "0.0.0.0"
        }
      ]
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ollama-service",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ollama"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "openwebui_task" {
  family                   = "openwebui-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      "name": "openwebui",
      "image": "ghcr.io/open-webui/open-webui:main",
      "essential": true,
      "portMappings": [
        {
          "name": "webui-port",
          "containerPort": 8080,
          "hostPort": 8080,
          "protocol": "tcp",
          "appProtocol": "http"
        }
      ],
      "environment": [
        {
          "name": "DATABASE_URL",
          "value": "postgresql://dbuser:${var.db_password}@${aws_db_instance.rds_instance.address}:${aws_db_instance.rds_instance.port}/mydatabase"
        },
        {
          "name": "OLLAMA_BASE_URL",
          "value": "http://ollama.internal:11434"
        },
        {
          "name": "OLLAMA_API_OVERRIDE_BASE_URL",
          "value": "http://ollama.internal:11434"
        },
        {
          "name": "OLLAMA_API_BASE_URL",
          "value": "http://ollama.internal:11434"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/openwebui-service",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "openwebui"
        }
      }
    }
  ])
}

resource "aws_security_group" "ollama_sg" {
  name   = "ecs-ollama-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow internal traffic to Ollama"
    from_port   = 11434
    to_port     = 11434
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "webui_sg" {
  name   = "ecs-webui-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow internal traffic to WebUI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_service" {
  name        = "ecs-service-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "openwebui_alb" {
  name               = "openwebui-alb"
  load_balancer_type = "application"
  subnets            = [for subnet in aws_subnet.public : subnet.id]
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "openwebui_tg" {
  name        = "openwebui-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
  }

    stickiness {
    type            = "lb_cookie"       # Використовує вбудований cookie від ALB
    enabled         = true
    cookie_duration = 86400             # Тривалість cookie в секундах (наприклад, 1 доба)
  }
}

resource "aws_lb_listener" "openwebui_listener" {
  load_balancer_arn = aws_lb.openwebui_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openwebui_tg.arn
  }
}

resource "aws_ecs_service" "ollama_service" {
  name                   = "ollama-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.ollama_task.arn
  desired_count          = 2
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  enable_execute_command = true

  network_configuration {
    subnets         = [for subnet in aws_subnet.private : subnet.id]
    security_groups = [aws_security_group.ollama_sg.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.service_namespace.arn

    service {
      port_name      = "ollama-port"
      discovery_name = "ollama"
      client_alias {
        port     = 11434
        dns_name = "ollama.internal"
      }
    }
  }
}

resource "aws_ecs_service" "webui_service" {
  name                   = "webui-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.openwebui_task.arn
  desired_count          = 2
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  enable_execute_command = true

  network_configuration {
    subnets         = [for subnet in aws_subnet.private : subnet.id]
    security_groups = [aws_security_group.webui_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.openwebui_tg.arn
    container_name   = "openwebui"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.openwebui_listener]

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.service_namespace.arn

    service {
      port_name      = "webui-port"
      discovery_name = "webui"
      client_alias {
        port     = 8080
        dns_name = "webui.internal"
      }
    }
  }
}


resource "aws_security_group" "rds_sg" {
  name   = "rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS Security Group"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group-ecs"
  subnet_ids = values(aws_subnet.rds)[*].id  

  tags = {
    Name = "RDS Subnet Group"
  }
}


resource "aws_db_instance" "rds_instance" {
  identifier           = "rds"
  allocated_storage    = var.db_allocated_storage
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  db_name              = "mydatabase"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true
  publicly_accessible  = false

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name

  tags = {
    Name = "RDS Instance"
  }
}
