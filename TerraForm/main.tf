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

# ----- Estblish Virtual Private Cloud ----- #
resource "aws_vpc" "demo" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "aap-demo-vpc"
  }
}

# ----- Estblish Virtual Private Cloud Subnet ----- #
resource "aws_subnet" "demo" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "aap-demo-subnet"
  }
}

# ----- Establish Establish Subnet Internet Gateway ----- #
resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id

  tags = {
    Name = "aap-demo-igw"
  }
}

# ----- Establish Route Table  ----- #
resource "aws_route_table" "demo" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }

  tags = {
    Name = "aap-demo-route-table"
  }
}

# ----- Establish Connection Between Subnet & Route Table ----- #
resource "aws_route_table_association" "demo" {
  subnet_id      = aws_subnet.demo.id
  route_table_id = aws_route_table.demo.id
}

# ----- Establish a Security Group for EC2 Instances ----- #
# ----- This is a list of characteristics that validates whether traffic should hit our EC2 instance. ----- #
resource "aws_security_group" "demo" {
  name        = "aap-demo-sg"
  description = "Security group for AAP demo instances"
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
    Name = "aap-demo-sg"
  }
}

# ----- Establish Public & Private Keys for EC2 Instances ----- #
resource "aws_key_pair" "demo" {
  key_name   = "aap-demo-key"
  public_key = file(pathexpand("~/.ssh/aap-demo-key.pub"))
}

# ----- Retrive for AMI Amazon EC2 Instance ----- #
# ----- The AMI is an image used to create the EC2 Instance OS  ----- #
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

resource "aws_instance" "amazon_linux" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.demo.id
  vpc_security_group_ids      = [aws_security_group.demo.id]
  key_name                    = aws_key_pair.demo.key_name
  associate_public_ip_address = true

  tags = {
    Name = "aap-demo-amazon-linux",
    OS   = "amazon_linux"
    Role = "compute"
  }
}

# ----- Retrive for AMI RHEL EC2 Instance ----- #
# ----- This is a list of characteristics that validates whether traffic should hit our EC2 instance. ----- #
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
resource "aws_instance" "rhel" {
  ami                    = data.aws_ami.rhel.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.demo.id
  vpc_security_group_ids = [aws_security_group.demo.id]
  key_name               = aws_key_pair.demo.key_name

  associate_public_ip_address = true

  tags = {
    Name = "aap-demo-rhel"
    OS   = "rhel"
    Role = "compute"
  }
}

# ----- Retrive for AMI Windows EC2 Instance ----- #
# ----- This is a list of characteristics that validates whether traffic should hit our EC2 instance. ----- #
resource "aws_instance" "windows" {
  ami           = data.aws_ssm_parameter.windows_ami.value
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.demo.id
  associate_public_ip_address = true

  key_name = "aap-windows-key-pair"

  vpc_security_group_ids = [
    aws_security_group.windows.id
  ]

  iam_instance_profile = aws_iam_instance_profile.windows_ssm.name

  user_data = <<-EOF
<powershell>

# Enable WinRM
winrm quickconfig -q

# Allow unencrypted WinRM traffic
winrm set winrm/config '@{AllowUnencrypted="false"}'

# Create a self-signed certificate
$cert = New-SelfSignedCertificate `
  -DnsName $env:COMPUTERNAME `
  -CertStoreLocation Cert:\LocalMachine\My

# Create an HTTPS WinRM listener
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
    Name = "aap-demo-windows"
    OS   = "windows"
    Role = "compute"
  }
}

data "aws_ssm_parameter" "windows_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

resource "aws_security_group" "windows" {
  name        = "aap-demo-windows-sg"
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aap-demo-windows-sg"
  }
}
# ----- Create an IAM Role for Windows ----- #
resource "aws_iam_role" "windows_ssm" {
  name = "aap-demo-windows-ssm-role"

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
  name = "aap-demo-windows-ssm-profile"
  role = aws_iam_role.windows_ssm.name
}