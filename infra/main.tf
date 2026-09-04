provider "aws" {
  region  = "eu-central-1"
  profile = "sbvh"

  default_tags {
    tags = {
      Project   = "muntje"
      ManagedBy = "opentofu"
    }
  }
}

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "sbvh"

  default_tags {
    tags = {
      Project   = "muntje"
      ManagedBy = "opentofu"
    }
  }
}

module "site" {
  source = "git::https://github.com/teranos/s3-r53-acm-cf.git?ref=428c86ccfc3145339b482c5541731f1dc01e4be1"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domains           = ["muntje.sbvh.nl"]
  route53_zone_name = "sbvh.nl"
  root_object       = "index.html"
}
