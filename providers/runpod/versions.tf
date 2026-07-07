terraform {
  required_version = ">= 1.5.7"

  required_providers {
    runpod = {
      source  = "decentralized-infrastructure/runpod"
      version = ">= 1.0.1"
    }
  }
}
