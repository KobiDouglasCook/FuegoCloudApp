output "instance_one_ip" {
  value = aws_instance.ec2_example.private_ip
}

output "instance_two_ip" {
  value = aws_instance.ec2_instance_2.private_ip
}

output "db_instance_address" {
  value = aws_db_instance.db_instance.address
}
