resource "aws_sns_topic" "alerts_topic" {
  name = "alerts-topic"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alerts_topic.arn
  protocol  = "email"
  endpoint  = "andervafla@gmail.com" 
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_host_count" {
  alarm_name          = "[llm]-[test]-[alb]-[high]-[unhealthy-host-count]"
  alarm_description   = "Unhealthy Host Count is above 0"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 300
  evaluation_periods  = 1
  dimensions = {
    LoadBalancer = aws_lb.openwebui_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.openwebui_tg.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_4xx_errors" {
  alarm_name          = "[llm]-[test]-[alb]-[medium]-[4XX-errors]"
  alarm_description   = "4XX errors sum exceeds 50 in 5 minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_4XX_Count"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 50
  period              = 300
  evaluation_periods  = 1
  dimensions = {
    LoadBalancer = aws_lb.openwebui_alb.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "[llm]-[test]-[alb]-[medium]-[5XX-errors]"
  alarm_description   = "5XX errors sum exceeds 10 in 5 minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 10
  period              = 300
  evaluation_periods  = 1
  dimensions = {
    LoadBalancer = aws_lb.openwebui_alb.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts_topic.arn]
}


resource "aws_cloudwatch_metric_alarm" "db_high_storage" {
  alarm_name          = "[llm]-[test]-[db]-[high]-[storage]"
  alarm_description   = "db high storage"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = 1000000000
  period              = 300
  evaluation_periods  = 1
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds_instance.identifier
  }
  alarm_actions = [aws_sns_topic.alerts_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "db_high_cpu" {
  alarm_name          = "[llm]-[test]-[db]-[high]-[cpu]"
  alarm_description   = "db high CPU"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  period              = 300
  evaluation_periods  = 1
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds_instance.identifier
  }
  alarm_actions = [aws_sns_topic.alerts_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "db_low_freeable_memory" {
  alarm_name          = "[llm]-[test]-[db]-[low]-[freeable-memory]"
  alarm_description   = "RDS: FreeableMemory is below threshold"
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = 200000000    
  period              = 300
  evaluation_periods  = 1
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds_instance.identifier
  }
  alarm_actions = [aws_sns_topic.alerts_topic.arn]
}


resource "aws_cloudwatch_metric_alarm" "webui_cpu_high" {
  alarm_name          = "webui-service-cpu-high"
  alarm_description   = "Alarm if CPU usage of webui-service > 80% for 1 minute"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 80
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.webui_service.name
  }

  alarm_actions = [aws_sns_topic.alerts_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "webui_memory_high" {
  alarm_name          = "webui-service-memory-high"
  alarm_description   = "Alarm if Memory usage of webui-service > 80% for 1 minute"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 80
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.webui_service.name
  }

  alarm_actions = [aws_sns_topic.alerts_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "webui_tasks_low" {
  alarm_name          = "webui-service-running-tasks-low"
  alarm_description   = "Alarm if webui-service has fewer than 1 running task"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = 1
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.webui_service.name
  }

alarm_actions = [aws_sns_topic.alerts_topic.arn]
}
