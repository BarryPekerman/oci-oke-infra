terraform {
  required_version = ">= 1.5.0"

  # State lives in HCP Terraform. Execution mode is Local: plans and applies
  # run on this machine with ~/.oci/config, HCP only stores and locks state.
  cloud {
    organization = "Berries-"
    workspaces {
      name = "oci-oke-infra"
    }
  }

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.28.0"
    }
  }
}

# Auth comes from the OCI CLI config (~/.oci/config), so the API key never
# sits in a tfvars file.
provider "oci" {
  config_file_profile = "DEFAULT"
  region              = var.region
}

# Cloudflare: the tunnel and DNS for the sites this cluster serves
# (cloudflare.tf). Reads CLOUDFLARE_API_TOKEN from the environment.
provider "cloudflare" {}
