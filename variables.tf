variable "aws-region" {
  default = "us-east-2"
}

variable "aws-keypair-name" {
  default = "devops.l2-prod"
}

variable "aws-s3bucket-name" {
  default = "devops.l2-s3bucket-prod-alexey-eshmetov"
}

# Variables for resources tags
variable "resource-name" {
  default = "devops.l2-prod"
}

variable "resource-env" {
  default = "prod"
}

variable "resource-owner" {
  default = "alexey_eshmetov"
}

variable "resource-project" {
  default = "devops.l2"
}
