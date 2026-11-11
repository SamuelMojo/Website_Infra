# Route 53 health checks for both clouds. The checks run every 30s from several
# regions; the primary check also drives a CloudWatch alarm so an outage emails you.

resource "aws_route53_health_check" "primary" {
  fqdn              = aws_cloudfront_distribution.cdn.domain_name
  type              = "HTTPS"
  port              = 443
  resource_path     = "/"
  request_interval  = 30
  failure_threshold = 3

  tags = { Name = "portfolio-primary-cloudfront" }
}

resource "aws_route53_health_check" "standby" {
  fqdn              = azurerm_storage_account.standby.primary_web_host
  type              = "HTTPS"
  port              = 443
  resource_path     = "/"
  request_interval  = 30
  failure_threshold = 3

  tags = { Name = "portfolio-standby-azure" }
}

resource "aws_sns_topic" "alerts" {
  provider = aws.us_east_1
  name     = "portfolio-health-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "primary_down" {
  provider            = aws.us_east_1
  alarm_name          = "portfolio-primary-down"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  dimensions          = { HealthCheckId = aws_route53_health_check.primary.id }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "standby_down" {
  provider            = aws.us_east_1
  alarm_name          = "portfolio-standby-down"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  dimensions          = { HealthCheckId = aws_route53_health_check.standby.id }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}
