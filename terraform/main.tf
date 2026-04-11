terraform {
  required_version = ">= 1.6"

  backend "s3" {}

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.47"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "hcloud" {
  token = var.hetzner_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
