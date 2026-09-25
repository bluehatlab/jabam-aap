terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================
# VPC
# ============================================================

resource "aws_vpc" "demo" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terr-demo-vpc"
  }
}

# ============================================================
# SUBNET
# ============================================================

resource "aws_subnet" "demo" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "terr-demo-subnet"
  }
}

# ============================================================
# INTERNET GATEWAY
# ============================================================

resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id

  tags = {
    Name = "terr-demo-igw"
  }
}

# ============================================================
# ROUTE TABLE
# ============================================================

resource "aws_route_table" "demo" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }

  tags = {
    Name = "terr-demo-route-table"
  }
}

resource "aws_route_table_association" "demo" {
  subnet_id      = aws_subnet.demo.id
  route_table_id = aws_route_table.demo.id
}

# ============================================================
# LINUX SECURITY GROUP
# ============================================================

resource "aws_security_group" "demo" {
  name        = "terr-demo-sg"
  description = "Security group for Terraform demo instances"
  vpc_id      = aws_vpc.demo.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terr-demo-sg"
  }
}

# ============================================================
# LINUX SSH KEY - ED25519
# Used by Amazon Linux and RHEL
# ============================================================

resource "aws_key_pair" "demo" {
  key_name   = "terr-demo-key"
  public_key = file(pathexpand("~/.ssh/terr-demo-key.pub"))
}

# ============================================================
# WINDOWS KEY - RSA
# Windows AMIs do not support ED25519 EC2 key pairs
# ============================================================

resource "aws_key_pair" "windows" {
  key_name   = "terr-demo-windows-key"
  public_key = file(pathexpand("~/.ssh/terr-demo-windows-key.pub"))
}

# ============================================================
# AMAZON LINUX AMI
# ============================================================

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ============================================================
# AMAZON LINUX INSTANCE
# ============================================================

resource "aws_instance" "amazon_linux" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.demo.id
  vpc_security_group_ids      = [aws_security_group.demo.id]
  key_name                    = aws_key_pair.demo.key_name
  associate_public_ip_address = true

  tags = {
    Name = "terr-demo-amazon-linux"
    OS   = "amazon_linux"
    Role = "compute"
  }
}

# ============================================================
# RHEL AMI
# ============================================================

data "aws_ami" "rhel" {
  most_recent = true

  owners = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-9.*_HVM-*-x86_64-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ============================================================
# RHEL INSTANCE
# ============================================================

resource "aws_instance" "rhel" {
  ami                         = data.aws_ami.rhel.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.demo.id
  vpc_security_group_ids      = [aws_security_group.demo.id]
  key_name                    = aws_key_pair.demo.key_name
  associate_public_ip_address = true

  tags = {
    Name = "terr-demo-rhel"
    OS   = "rhel"
    Role = "compute"
  }
}

# ============================================================
# WINDOWS SERVER AMI
# ============================================================

data "aws_ssm_parameter" "windows_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

# ============================================================
# WINDOWS SECURITY GROUP
# ============================================================

resource "aws_security_group" "windows" {
  name        = "terr-demo-windows-sg"
  description = "Allow WinRM HTTPS access to Windows EC2"
  vpc_id      = aws_vpc.demo.id

  ingress {
    description = "WinRM HTTPS"
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terr-demo-windows-sg"
  }
}

# ============================================================
# WINDOWS IAM ROLE FOR SSM
# ============================================================

resource "aws_iam_role" "windows_ssm" {
  name = "terr-demo-windows-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "windows_ssm" {
  role       = aws_iam_role.windows_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "windows_ssm" {
  name = "terr-demo-windows-ssm-profile"
  role = aws_iam_role.windows_ssm.name
}

# ============================================================
# WINDOWS SERVER INSTANCE
# ============================================================

resource "aws_instance" "windows" {
  ami           = data.aws_ssm_parameter.windows_ami.value
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.demo.id
  associate_public_ip_address = true

  # Windows requires an RSA EC2 key pair
  key_name = aws_key_pair.windows.key_name

  vpc_security_group_ids = [
    aws_security_group.windows.id
  ]

  iam_instance_profile = aws_iam_instance_profile.windows_ssm.name

  user_data = <<-EOF
<powershell>

# Enable WinRM
winrm quickconfig -q

# Disable unencrypted WinRM
winrm set winrm/config '@{AllowUnencrypted="false"}'

# Create self-signed certificate
$cert = New-SelfSignedCertificate `
  -DnsName $env:COMPUTERNAME `
  -CertStoreLocation Cert:\LocalMachine\My

# Create HTTPS WinRM listener
winrm create winrm/config/Listener?Address=*+Transport=HTTPS `
  "@{Hostname='$env:COMPUTERNAME';CertificateThumbprint='$($cert.Thumbprint)'}"

# Allow WinRM HTTPS through Windows Firewall
New-NetFirewallRule `
  -DisplayName "WinRM HTTPS" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 5986 `
  -Action Allow

</powershell>
EOF

  tags = {
    Name = "terr-demo-windows"
    OS   = "windows"
    Role = "compute"
  }
}