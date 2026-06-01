provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "demo_bucket" {
  bucket = "${var.name_prefix}-bucket-demo"
}