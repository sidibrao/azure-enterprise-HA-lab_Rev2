locals {
  common_tags = merge({
    environment = "lab"
    workload    = "erp"
    costCenter  = "learning"
    managedBy   = "terraform"
  }, var.tags)

  policy_scope = "disabled-for-restricted-sandbox"
}
