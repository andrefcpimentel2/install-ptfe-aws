provider "aws" {
  region = var.region
}

data "http" "myipaddr" {
    url = "http://ipv4.icanhazip.com"
}


data "template_file" "userdata_win" {
  template = <<EOF
<script>
echo "" > _INIT_STARTED_
net user ${var.admin_username} /add /y
net user ${var.admin_username} ${var.admin_password}
net localgroup administrators ${var.admin_username} /add
echo ${base64encode(file("./test.txt"))} > tmp2.b64 && certutil -decode tmp2.b64 C:/test.txt
echo "" > _INIT_COMPLETE_
</script>
<persist>false</persist>
EOF
}


resource "aws_instance" "ptfe" {
  ami           = data.aws_ami.amazon_windows_2019.image_id
  instance_type = var.instance_type
  key_name      = var.key_name
  
  connection {
    type     = "winrm"
    user     = var.admin_username
    password = var.admin_password

    # set from default of 5m to 10m to avoid winrm timeout
    timeout = "10m"
  }
  
  user_data = data.template_file.userdata_win.rendered


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
    from_port   = 5985
    to_port     = 5986
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
    from_port   = 3389
    to_port     = 3389
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

output "publicdns" {
  value = aws_eip.ptfe.public_dns
}

