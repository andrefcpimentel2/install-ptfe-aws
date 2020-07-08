provider "aws" {
  region = var.region
}

data "http" "myipaddr" {
    url = "http://ipv4.icanhazip.com"
}



resource "aws_instance" "ptfe" {
  ami           = data.aws_ami.amazon_windows_2019.image_id
  instance_type = var.instance_type
  key_name      = var.key_name
  
  user_data = <<EOF
  
Start-Transcript -Path C:\Deploy.Log
Write-Host "Setup WinRM for $RemoteHostName"
net user ${var.admin_username} '${var.admin_password}' /add /y
net localgroup administrators ${var.admin_username} /add
Write-Host "quickconfigure  WinRM"
winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="300"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
Write-Host "Open Firewall Port for WinRM"
netsh advfirewall firewall add rule name="Windows Remote Management (HTTP-In)" dir=in action=allow protocol=TCP localport=$WinRmPort
netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow
netsh advfirewall firewall add rule name="WinRM 5986" protocol=TCP dir=in localport=5986 action=allow
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Write-Host "configure WinRM as a Service"
net stop winrm
sc.exe config winrm start=auto
net start winrm
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) 
choco feature enable -n allowGlobalConfirmation  
choco install curl 
choco install firefox
choco install vault

Stop-Transcript

EOF


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

