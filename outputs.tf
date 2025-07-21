output "instance_id" {
  value = aws_instance.gpu_instance.id
}

output "public_ip" {
  value = aws_instance.gpu_instance.public_ip
}

