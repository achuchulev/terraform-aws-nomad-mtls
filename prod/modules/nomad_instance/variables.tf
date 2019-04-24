variable "nomad_instance_count" {
  default = "3"
}

variable "access_key" {}
variable "secret_key" {}

variable "instance_role" {
  description = "Nomad instance type"
  default     = "server"
}

variable "public_key" {}

variable "region" {
  default = "us-east-2"
}

variable "ami" {}
variable "instance_type" {}
variable "subnet_id" {}

variable "vpc_security_group_ids" {
  type = "list"
}

variable "role_name" {
  description = "Name for IAM role, defaults to \"nomad-cloud-auto-join-aws\"."
  default     = "nomad-cloud-auto-join-aws"
}

variable "dc" {
  type    = "string"
  default = "dc1"
}

variable "nomad_region" {
  type    = "string"
  default = "global"
}

variable "authoritative_region" {
  type    = "string"
  default = "global"
}
