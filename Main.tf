provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAW7FS2RWLIEU4DWGO"
  secret_key = "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"
}

resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    env = "DEV_VPC"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "dev-internet_gateway" {
  vpc_id = aws_vpc.dev-vpc.id
}

#RouteTable for VPC's subnet
resource "aws_route_table" "dev-route_table" {
  vpc_id = aws_vpc.dev-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev-internet_gateway.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.dev-internet_gateway.id
  }

  tags = {
    Name = "dev-routetable"
  }
}

#Subnet for dev-vpc
resource "aws_subnet" "dev-subnet" {
  vpc_id     = aws_vpc.dev-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    "Name" = "dev-subnet"
  }
}

resource "aws_route_table_association" "dev-route-table-association" {
  subnet_id      = aws_subnet.dev-subnet.id
  route_table_id = aws_route_table.dev-route_table.id
}

resource "aws_security_group" "dev-security-group" {
  name        = "allow_web_traffic"
  description = "Allow WEB inbound traffic"
  vpc_id      = aws_vpc.dev-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "dev-web-traffic"
  }
}

resource "aws_network_interface" "dev-network-interface" {
  subnet_id       = aws_subnet.dev-subnet.id
  private_ips     = ["10.0.1.20"]
  security_groups = [aws_security_group.dev-security-group.id]

}

resource "aws_eip" "dev-eip" {
  vpc = true
  network_interface = aws_network_interface.dev-network-interface.id
  associate_with_private_ip = "10.0.1.20"
  depends_on = [
    aws_internet_gateway.dev-internet_gateway
  ]
}

resource "aws_instance" "dev-web-server" {
    ami = "ami-00874d747dde814fa"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "dev-access"

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.dev-network-interface.id
    }

    user_data = <<-EOF
                  #!/bin/bash
                  sudo apt update -y
                  sudo apt install apache2 -y
                  sudo systemctl start apache2
                  sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                  EOF
}

