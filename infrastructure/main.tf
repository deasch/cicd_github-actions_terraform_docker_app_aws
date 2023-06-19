variable "repo_version"{
  default = "v0.0.0.1"
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
resource "aws_key_pair" "demokey" {
  key_name   = var.key_name
  public_key = file(var.public_key)
}


# ========== NETWORKING - VPC
# ===== VPC
resource "aws_vpc" "demo_vpc" {
  cidr_block           = var.cidr_block
  instance_tenancy     = var.tenancy
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name}-vpc"
    Environment = "aws_sandbox"
  }
}
# ===== SECURITY GROUP
resource "aws_security_group" "demosg" {
  name        = "Demo Security Group"
  vpc_id      = aws_vpc.demo_vpc.id

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
resource "aws_subnet" "demo_subnet" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = var.cidr_block_subnet
  availability_zone       = data.aws_availability_zones.az.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.name}-subnet"
    Environment = "aws_sandbox"
  }
}


# ========== NETWORKING - GATEWAYS
# ===== INTERNET GATEWAY
# Internet Gateway
resource "aws_internet_gateway" "demo_gateway" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name        = "${var.name}-igw"
    Environment = "aws_sandbox"
  }
}


# ========== NETWORKING - ROUTING TABLES
# ===== ROUTE TABLE
# AWS Route Table
resource "aws_route_table" "demo_route_table" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_gateway.id
  }

  tags = {
    Name        = "${var.name}-route"
    Environment = "aws_sandbox"
  }
}
# ===== ROUTE TABLE ASSOCIATION
# Associate public subnet to route table
resource "aws_route_table_association" "demo_association" {
  subnet_id      = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.demo_route_table.id
}


# ========== COMPUTE
# ===== S3 BUCKET
# Storing state file on S3 backend
terraform {
  backend "s3" {
    bucket = "tf-state-dhsoni"
    region = "us-west-2"
    key    = "terraform.tfstate"
  }
}
# ===== EC2 INSTANCE
resource "aws_instance" "demo_instance" {

  ami                    = var.ami_id
  instance_type          = var.instance_type
  availability_zone      = data.aws_availability_zones.az.names[0]
  subnet_id              = aws_subnet.demo_subnet.id
  key_name               = aws_key_pair.demokey.id
  vpc_security_group_ids = [aws_security_group.demosg.id]

  tags = {
    Name        = "${var.name}-instance"
    Environment = "aws_sandbox"
  }

  # SSH into instance 
  connection {
    # The default username for our AMI
    user = "ec2-user"
    # Private key for connection
    private_key = file(var.private_key)
    # Type of connection
    type = "ssh"
    # Host
    host = self.public_ip

  }

  # Installing splunk & creating distributed indexer clustering on newly created instance
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo amazon-linux-extras install docker -y",
      "sudo service docker start",
      "sudo usermod -a -G docker ec2-user",
      "sudo chkconfig docker on",
      "sudo yum install -y git",
      "sudo chmod 666 /var/run/docker.sock",
      "docker pull dhruvin30/dhsoniweb:v1",
      "docker run -d -p 80:80 dhruvin30/dhsoniweb:v1"
    ]
  }

}









# CIDR Block for VPC
variable "cidr_block" {}

# Instance Tenancy 
variable "tenancy" {}

# Subnet CIDR
variable "cidr_block_subnet" {}

# Tags
variable "name" {}

# Region
variable "region" {}

# AMI ID
variable "ami_id" {}

# Instance Type
variable "instance_type" {}

# Defining Public Key
variable "public_key" {
  default = "tests.pub"
}

# Defining Private Key
variable "private_key" {
  default = "tests.pem"
}

# Definign Key Name for connection
variable "key_name" {
  default     = "tests"
  description = "Desired name of AWS key pair"
}









