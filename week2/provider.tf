terraform {
  required_version = ">= 1.3.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.0"
    }
  }
}

# Credentials are read from ~/.oci/config, never from this repo. The profile and
# region are variables so the same code can target another tenancy or region.
provider "oci" {
  config_file_profile = var.oci_config_profile
  region              = var.oci_region
}
