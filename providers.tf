variable "aws_iam_info" {}

provider "aws" {
  shared_credentials_file = var.aws_iam_info.path_credentials_file
  profile                 = var.aws_iam_info.profile
  region                  = var.aws_iam_info.region
}
