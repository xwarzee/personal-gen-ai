output "ec2_public_ip" {
  value = aws_instance.gpu_instance.public_ip
}

output "https_url" {
  value = "https://${aws_instance.gpu_instance.public_ip}"
}
