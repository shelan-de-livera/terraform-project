output "alb_dns_name" {
  value       = "http://${aws_lb.app_lb.dns_name}"
  description = "The DNS name of the Application Load Balancer, with HTTP protocol"
}