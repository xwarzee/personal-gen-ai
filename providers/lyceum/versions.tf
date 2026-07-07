terraform {
  required_version = ">= 1.5.7"

  required_providers {
    # Lyceum n'a pas de provider Terraform natif : on pilote son API REST
    # (https://api.lyceum.technology/api/v2/external) via le provider restapi.
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 1.20.0"
    }
  }
}
