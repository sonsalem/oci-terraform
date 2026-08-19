terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.30.0"
    }
  }
}

# Credentials are read from ~/.oci/config, never from this repo — same pattern as
# Weeks 1 and 2. The profile and region are variables so the same code can target
# another tenancy or region.
provider "oci" {
  config_file_profile = var.oci_config_profile
  region              = var.region
}
