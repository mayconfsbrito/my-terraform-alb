# my-terraform-alb

My Terraform POC to learn and understand how this terrific infra-as-code works!

This repo creates some infra assets in Amazon AWS:
* 2 EC2 Servers
  * 1 Nginx
  * 1 Apache24
* 1 Application Load Balancer
* 2 Security groups
  * 1 for the ALB
  * 1 for EC2 instances 
* Network issues like VPC, Subnet, Target Group, Listeners and etc.

### Prerequisites ###

* Terraform >= 0.12.25
* Aws cli shared credentials file

## How to Use ##

### Run ###

After that, just init, plan and apply your infra!

### Example ####
```
terraform init
terraform plan -out myplan.plan
terraform apply myplan.plan
```



