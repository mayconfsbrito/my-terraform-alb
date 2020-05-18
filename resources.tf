################################## VARIABLES ##################################
variable "ec2_info" {}
variable "network_address_space" {
  default = "10.1.0.0/16"
}
variable "subnet_address_cidr_blocks" {
  default = ["10.1.0.0/24", "10.1.1.0/24"]
}

##################################### VPC #####################################
resource "aws_vpc" "vpc" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = "true"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

################################### SUBNETS ###################################
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  cidr_block              = var.subnet_address_cidr_blocks[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
}
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  cidr_block              = var.subnet_address_cidr_blocks[1]
  availability_zone       = data.aws_availability_zones.available.names[1]
}

################################# ROUTE TABLE ##################################
resource "aws_route_table" "default" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.default.id
}
resource "aws_route_table_association" "rta-subnet2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.default.id
}

################################ SECURIT GROUPS ################################
module "web_server_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name                = "web_sg"
  vpc_id              = aws_vpc.vpc.id
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp", "http-80-tcp"]
  egress_rules        = ["http-80-tcp"]
}

resource "aws_security_group" "lb-sg" {
  name   = "nginx_elb_sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
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

################################## INSTANCES ##################################
resource "aws_instance" "nginx" {
  instance_type          = var.ec2_info.instance_type
  ami                    = data.aws_ami.ami-amz-linux.id
  subnet_id              = aws_subnet.subnet2.id
  vpc_security_group_ids = [module.web_server_sg.this_security_group_id]
  key_name               = var.ec2_info.key_name

  connection {
    user        = var.ec2_info.username
    type        = "ssh"
    host        = self.public_ip
    private_key = file(var.ec2_info.private_key_path)
  }

  tags = {
    Name = "web_nginx"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install nginx -y",
      "sudo service nginx start"
    ]
  }
}

resource "aws_instance" "apache" {
  instance_type          = var.ec2_info.instance_type
  ami                    = data.aws_ami.ami-amz-linux.id
  subnet_id              = aws_subnet.subnet2.id
  vpc_security_group_ids = [module.web_server_sg.this_security_group_id]
  key_name               = var.ec2_info.key_name

  connection {
    user        = var.ec2_info.username
    type        = "ssh"
    host        = self.public_ip
    private_key = file(var.ec2_info.private_key_path)
  }

  tags = {
    Name = "web_apache"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd24 amazon-linux-extras -y",
      "sudo cp /var/www/noindex/index.html /var/www/html/",
      "sudo service httpd start",
      "sudo chkconfig httpd on"
    ]
  }
}

################################ LOAD BALANCER ################################
resource "aws_lb_target_group" "tg_web" {
  name     = "tg-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 15
    protocol            = "HTTP"
  }
}

################################ TARGET GROUPS ################################
resource "aws_lb_target_group_attachment" "nginx" {
  target_group_arn = aws_lb_target_group.tg_web.arn
  target_id        = aws_instance.nginx.id
}

resource "aws_lb_target_group_attachment" "apache" {
  target_group_arn = aws_lb_target_group.tg_web.arn
  target_id        = aws_instance.apache.id
}

resource "aws_lb" "lb_web" {
  name            = "lb-web"
  internal        = false
  security_groups = [aws_security_group.lb-sg.id]
  subnets         = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  enable_deletion_protection = false
  depends_on                 = [aws_internet_gateway.igw]
}

################################ LB LISTENERS ################################
resource "aws_lb_listener" "web_80" {
  load_balancer_arn = aws_lb.lb_web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_web.arn
  }
}


