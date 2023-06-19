variable "repo_version"{
  default = "v0.0.0.3"
}


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


# ========== PROVIDER
# ===== AWS
provider "aws" {
  region = "eu-central-1"
}


# ========== AVAILABILITY ZONE
data "aws_availability_zones" "az" {}


# ========== IAM
# ===== KEY PAIR
# aws_sandbox_keypair


# ========== NETWORKING - VPC
# ===== VPC
resource "aws_vpc" "aws_sandbox_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name        = "aws_sandbox_vpc"
    Environment = "aws_sandbox"
  }
}
# ===== SECURITY GROUP
resource "aws_security_group" "aws_sandbox_sg" {
  name        = "aws_sandbox_sg"
  vpc_id      = aws_vpc.aws_sandbox_vpc.id

  # Inbound Rules
  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Rules
  # Internet access to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ========== NETWORKING - SUBNETS
# ===== PUBLIC SUBNET
# AWS Subnet
resource "aws_subnet" "aws_sandbox_subnet" {
  vpc_id                  = aws_vpc.aws_sandbox_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = {
    Name        = "aws_sandbox_subnet"
    Environment = "aws_sandbox"
  }
}


# ========== NETWORKING - GATEWAYS
# ===== INTERNET GATEWAY
# Internet Gateway
resource "aws_internet_gateway" "aws_sandbox_igw" {
  vpc_id = aws_vpc.aws_sandbox_vpc.id
  tags = {
    Name        = "aws_sandbox_igw"
    Environment = "aws_sandbox"
  }
}


# ========== NETWORKING - ROUTING TABLES
# ===== ROUTE TABLE
# AWS Route Table
resource "aws_route_table" "aws_sandbox_routetable" {
  vpc_id = aws_vpc.aws_sandbox_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_sandbox_igw.id
  }
  tags = {
    Name        = "aws_sandbox_routetable"
    Environment = "aws_sandbox"
  }
}
# ===== ROUTE TABLE ASSOCIATION
# Associate public subnet to route table
resource "aws_route_table_association" "demo_association" {
  subnet_id      = aws_subnet.aws_sandbox_subnet.id
  route_table_id = aws_route_table.aws_sandbox_routetable.id
}


# ========== COMPUTE
# ===== S3 BUCKET


# ===== EC2 INSTANCE
resource "aws_instance" "sandbox_ec2_instance" {

  ami                    = "ami-0b2ac948e23c57071"
  instance_type          = "t2.micro"
  availability_zone      = data.aws_availability_zones.az.names[0]
  subnet_id              = aws_subnet.aws_sandbox_subnet.id
  key_name               = "aws_sandbox_keypair"
  vpc_security_group_ids = [aws_security_group.aws_sandbox_sg.id]
  user_data = "${file("${path.module}/userdata_install-docker.sh")}"
  tags = {
    Name        = "sandbox_ec2_instance"
    Environment = "aws_sandbox"
  }

}
