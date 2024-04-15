variable "vpc_name" {
  default      = "prod-vpc"
}

variable "vpc_cidr" {
  default      = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default      = "10.0.1.0/24"
}

variable "public_subnet_cidr2" {
  default      = "10.0.3.0/24"
}

variable "private_subnet_cidr" {
  default      = "10.0.2.0/24"
}

variable "subnet_availability_zone_1" {
  default      = "us-east-1a"
}

variable "subnet_availability_zone_2" {
  default      = "us-east-1b"
}

variable "public_subnet_name" {
  default      = "public-subnet-1"
}

variable "public_subnet_name2" {
  default      = "public-subnet-2"
}

variable "private_subnet_name" {
  default      = "private-subnet-1"
}

variable "application_lb_name" {
  default      = "application-lb"
}

variable "asg_name" {
  default      = "production-asg"
}

variable "lt_name" {
  default      = "production-lt"
}

variable "lt_ebs_root_size" {
  default      = "20"
}

variable "lt_ebs_secondary_size" {
  default      = "50"
}

variable "lt_iam_profile" {
  default      = "application-role"
}

variable "lt_image" {
  default      = "ami-051f8a213df8bc089"
}

variable "tg_name" {
  default      = "application-tg"
}

variable "autoscaling_policy_name" {
  default      = "cpuloadscale"
}

variable "tg_error_alarm_name" {
  default      = "tg_connection_error"
}

variable "ssh_key_name" {
  default      = "abhinav"
}
