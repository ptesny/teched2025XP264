//
terraform {
  required_providers {
    btp = {
      source  = "SAP/btp"
    }
    jq = {
      source  = "massdriver-cloud/jq"
    }
    http-full = {
      source = "salrashid123/http-full"
    }     
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    kubectl = {
      source  = "alekc/kubectl"
    }  
    qrcode = {
      source = "jackivanov/qrcode"
      //version = "1.0.0"
    }
  }
}

provider "jq" {}
provider "http-full" {}

# https://registry.terraform.io/providers/jackivanov/qrcode/latest/docs
#
provider "qrcode" {
  # Configuration options
}

provider "btp" {
  globalaccount  = var.BTP_GLOBAL_ACCOUNT
  cli_server_url = var.BTP_BACKEND_URL
  idp            = var.BTP_CUSTOM_IDP
}


provider "kubernetes" {}
provider "kubectl" {}

# https://developer.hashicorp.com/terraform/language/backend/kubernetes#configuration-variables
# https://developer.hashicorp.com/terraform/language/backend/kubernetes#secret_suffix
# the secret will be named in the format: tfstate-{workspace}-{secret_suffix}
terraform {
  backend "kubernetes" {
    secret_suffix = "teched25"
    namespace     = "quovadis-btp"
  }
}