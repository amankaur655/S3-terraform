provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "splunk_vpc" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "splunk-vpc"
  }
}

# Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.splunk_vpc.id
  cidr_block        = "10.10.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.splunk_vpc.id
  cidr_block        = "10.10.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1b"
  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.splunk_vpc.id
  cidr_block        = "10.10.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.splunk_vpc.id
  cidr_block        = "10.10.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "private-subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.splunk_vpc.id
  tags = {
    Name = "internet-gateway"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.splunk_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public-route-table"
  }
}

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public_rt_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group
resource "aws_security_group" "splunk_sg" {
  vpc_id = aws_vpc.splunk_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "splunk-sg"
  }
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# EC2 Instance
resource "aws_instance" "splunk_instance" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.small"
  key_name      = "ec2-key"
  subnet_id     = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.splunk_sg.id]

  root_block_device {
    volume_size = 25
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install wget -y
                cd /opt
                sudo wget -O splunk-9.0.4.1-419ad9369127-Linux-x86_64.tgz "https://download.splunk.com/products/splunk/releases/9.0.4.1/linux/splunk-9.0.4.1-419ad9369127-Linux-x86_64.tgz"
                sudo tar -zxvf splunk-9.0.4.1-419ad9369127-Linux-x86_64.tgz -C /opt
                sudo /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd "abcd1234"
                sudo /opt/splunk/bin/splunk enable boot-start
              EOF

  tags = {
    Name = "splunk-instance"
  }
}

# Outputs
output "vpc_id" {
  value = aws_vpc.splunk_vpc.id
}

output "splunk_sg_id" {
  value = aws_security_group.splunk_sg.id
}

output "splunk_instance_public_ip" {
  value = aws_instance.splunk_instance.public_ip
}

