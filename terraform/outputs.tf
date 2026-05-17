output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "app_bucket_name" {
  description = "Name of the application S3 bucket"
  value       = module.s3.app_bucket_name
}

output "log_bucket_name" {
  description = "Name of the access-log S3 bucket"
  value       = module.s3.log_bucket_name
}

output "app_instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.instance_id
}
