terraform {
  backend "s3" {
    bucket         = "dansport-tfstate-bogdan-20250830" 
    key            = "lesson-5/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
