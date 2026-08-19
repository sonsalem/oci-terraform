terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.30.0"
    }
  }
}

# Credentials come from ~/.oci/config, never from this repo — same as weeks 1 and 2.
provider "oci" {
  config_file_profile = var.oci_config_profile
  region              = var.region
}
