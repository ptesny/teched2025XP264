//
module "k8s_context" {
  source         = "./modules/k8s"

  BTP_SUBACCOUNT = var.BTP_SUBACCOUNT
  BTP_SA_REGION  = var.BTP_SA_REGION
  admin_groups   = var.admin_groups
}