# Configure the AWS provider with the region set in variables
provider "aws" {
  region = local.region
}