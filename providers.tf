variable "aws_iam_info" {}

provider "aws" {
  access_key = var.aws_iam_info.aws_access_key
  secret_key = var.aws_iam_info.aws_secret_key
  region     = var.aws_iam_info.region
}
