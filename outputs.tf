output "alb_dns" {
  value = aws_lb.prod_lb.dns_name
}

