terraform {
  required_version = ">= 1.3"
  backend "s3" {
    bucket         = "state-file-291025-1"  
    key            = "infra-repo/terraform.tfstate"
    region         = "ap-south-1"                    
    encrypt        = true
  }
}
