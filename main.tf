provider "aws" {
  region = var.region
}

data "http" "myipaddr" {
    url = "http://ipv4.icanhazip.com"
}



resource "aws_instance" "ptfe" {
  ami           = var.ami[var.region]
  instance_type = var.instance_type
  key_name      = var.key_name
  user_data     = file("./init_install.sh")

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_type = "gp2"
    volume_size = var.volume_size
  }

  vpc_security_group_ids = [
    aws_security_group.ptfe_sg.id,
  ]

  tags = {
    Name  = "PTFE"
    owner = var.tag_owner
    TTL   = var.tag_ttl
  }
}

resource "aws_eip" "ptfe" {
  instance = aws_instance.ptfe.id
}


resource "aws_security_group" "ptfe_sg" {
  name        = "andre_ptfe_inbound"
  description = "Allow ptfe ports and ssh from Anywhere"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myipaddr.body)}/32"]
  }

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8800
    to_port     = 8800
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9870
    to_port     = 9880
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

output "install_url" {
  value = "http://${aws_instance.ptfe.public_dns}:8800"
}

