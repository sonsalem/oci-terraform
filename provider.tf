terraform {
  required_version = ">= 1.3.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.0"
    }
  }
}

# Credentials are read from the DEFAULT profile in ~/.oci/config, never from this repo.
provider "oci" {
  config_file_profile = "DEFAULT"
  region              = var.oci_region
}
