terraform {
  required_version = ">= 1.5.7"

  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = ">= 0.60"
    }
  }
}
