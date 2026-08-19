############################################
# modules/subnet/versions.tf
# A reusable module declares the providers it
# needs itself, so it can be consumed by any
# root configuration without relying on that
# root's provider block being compatible.
############################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.30.0"
    }
  }
}
