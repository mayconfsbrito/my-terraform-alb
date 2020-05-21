################################### OUTPUTS ###################################
output "aws_alb_dns_name" {
  value = aws_lb.lb_web.dns_name
}
