#----------------------------------------------------------------------------------------------------/*
# Task definition:                                                                                    |
# Необходимо создать шаблон Cloudformation, который будет создавать инфраструктуру:                   |
# Вся инфраструктура должна подниматься автоматически, без ручных действий                            |
# - Load balancer                                                                                     |
# - 2 EC2 инстанса                                                                                    |
# - Должен быть установлен веб-сервер apache/nginx                                                    |
# - При открытии ссылки на load balancer должна открываться html-страничка с надписью “Hello world”   |
# - Выключение любого из 2-х инстансов не должно нарушать работоспособности странички                 |
# - 1х* html страничка должна отдавать “Hello from <ip адрес машины>"                                 |
# - 2х* html страничка еще должна содержать картинку, которая берется с S3 бакета                     |
# - 10х* Все описанное выше должно быть сделано на Terraform                                          |
#----------------------------------------------------------------------------------------------------*/
provider "aws" {
  region  = var.aws-region
  profile = "terraform"
}

resource "aws_key_pair" "keypair" {
  key_name   = var.aws-keypair-name
  public_key = file("~/.ssh/id_rsa.pub")

  tags = {
    Owner = var.resource-owner
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name    = var.resource-name
    Project = var.resource-project
    Owner   = var.resource-owner
    Env     = var.resource-env
  }
}

resource "aws_subnet" "subnet-00" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "172.16.0.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name    = "devops.l2-prod-us-east-2a"
    Project = var.resource-project
    Owner   = var.resource-owner
    Env     = var.resource-env
  }
}

resource "aws_subnet" "subnet-01" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "172.16.1.0/24"
  availability_zone = "us-east-2c"

  tags = {
    Name    = "devops.l2-prod-us-east-2c"
    Project = var.resource-project
    Owner   = var.resource-owner
    Env     = var.resource-env
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = var.resource-name
    Project = var.resource-project
    Owner   = var.resource-owner
    Env     = var.resource-env
  }
}

resource "aws_default_route_table" "r" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name    = var.resource-name
    Project = var.resource-project
    Owner   = var.resource-owner
    Env     = var.resource-env
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http inbound/outbound traffic for nginx"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "http for nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }


  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "https for nginx"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "ping"
    protocol    = "ICMP"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "devops.l2-ec2-prod"
    Project = var.resource-project
    Owner   = var.resource-owner
    Env     = var.resource-env
  }
}

resource "aws_instance" "instance" {
  ami                    = "ami-07c1207a9d40bc3bd" # Ubuntu server 18.04 LTS image
  instance_type          = "t2.micro"
  key_name               = var.aws-keypair-name
  subnet_id              = aws_subnet.subnet-00.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  user_data              = file("user_data.sh")
  count                  = 2

  tags = {
    Name    = "web-0${count.index}-prod"
    Project = var.resource-project
    Owner   = var.resource-owner
    Env     = var.resource-env
  }
}

resource "aws_lb" "lb-nginx" {
  name               = "nginx-load-balancer"
  internal           = false
  load_balancer_type = "network" 
  subnets = [
    aws_subnet.subnet-00.id,
    aws_subnet.subnet-01.id
  ]
  depends_on = [aws_instance.instance]

  tags = {
    Name    = "web-prod"
    Project = var.resource-project
    Owner   = var.resource-owner
    Env     = var.resource-env
  }
}

resource "aws_lb_target_group" "lb-nginx-tg" {
  name          = "lb-nginx-tg"
  port          = 80
  protocol      = "TCP"
  target_type   = "instance"
  vpc_id        = aws_vpc.vpc.id
  health_check { 
    interval = 10
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "lb-nginx-tg-attach-0" {
  target_group_arn = aws_lb_target_group.lb-nginx-tg.arn
  target_id        = aws_instance.instance.0.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "lb-nginx-tg-attach-1" {
  target_group_arn = aws_lb_target_group.lb-nginx-tg.arn
  target_id        = aws_instance.instance.1.id
  port             = 80
}

resource "aws_lb_listener" "lb-nginx" {
  load_balancer_arn = aws_lb.lb-nginx.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-nginx-tg.arn

  }
}

resource "aws_s3_bucket" "s3-bucket" {
  bucket = var.aws-s3bucket-name
  acl    = "public-read"
  tags = {
    Name    = "devops.l2-prod"
    Project = var.resource-project
    Owner   = var.resource-owner
    Env     = var.resource-env
  }
}

resource "aws_s3_bucket_object" "file_upload" {
  bucket = var.aws-s3bucket-name
  acl    = "public-read"
  key    = "hello.jpg"
  source = "./hello.jpg"
  depends_on = [
    aws_s3_bucket.s3-bucket
  ]
}



