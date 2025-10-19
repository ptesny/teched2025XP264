#
terraform {
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.16.1"
    }
    jq = {
      source  = "massdriver-cloud/jq"
    }
    http-full = {
      source = "salrashid123/http-full"
      version = "1.3.1"
    }        
    qrcode = {
      source = "jackivanov/qrcode"
    }
  }
}