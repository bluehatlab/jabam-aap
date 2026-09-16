output "vpc_id" {
  description = "ID of the demo VPC"
  value       = aws_vpc.demo.id
}

output "subnet_id" {
  description = "ID of the demo subnet"
  value       = aws_subnet.demo.id
}

output "amazon_linux_public_ip" {
  description = "Public IP address of the Amazon Linux EC2 instance"
  value       = aws_instance.amazon_linux.public_ip
}

output "amazon_linux_instance_id" {
  description = "Instance ID of the Amazon Linux EC2 instance"
  value       = aws_instance.amazon_linux.id
}

output "rhel_public_ip" {
  description = "Public IP address of the RHEL EC2 instance"
  value       = aws_instance.rhel.public_ip
}

output "rhel_instance_id" {
  description = "Instance ID of the RHEL EC2 instance"
  value       = aws_instance.rhel.id
}

output "windows_public_ip" {
  description = "Public IP address of the Windows EC2 instance"
  value       = aws_instance.windows.public_ip
}

output "windows_instance_id" {
  description = "Instance ID of the Windows EC2 instance"
  value       = aws_instance.windows.id
}