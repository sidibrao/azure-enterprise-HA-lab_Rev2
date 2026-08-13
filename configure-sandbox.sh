#!/usr/bin/env bash
set -euo pipefail

if ! az account show >/dev/null 2>&1; then
  echo "Azure CLI is not logged in. Run: az login --use-device-code"
  exit 1
fi

subscription_id=$(az account show --query id --output tsv)
tenant_id=$(az account show --query tenantId --output tsv)
resource_group_name=$(az group list --query "[?contains(name, 'playground-sandbox')].name | [0]" --output tsv)

if [[ -z "${resource_group_name}" ]]; then
  echo "No visible resource group containing 'playground-sandbox' was found."
  echo "Run 'az group list -o table', then create terraform.tfvars from terraform.tfvars.example."
  exit 1
fi

resource_group_location=$(az group show --name "${resource_group_name}" --query location --output tsv)

cat >terraform.tfvars <<EOF
subscription_id = "${subscription_id}"
tenant_id       = "${tenant_id}"

existing_resource_group_name = "${resource_group_name}"
location                     = "${resource_group_location}"
prefix                       = "contoso-lab1"

enable_management_group = false
deploy_test_vm          = true
enable_lab4              = true
lab4_vm_size             = "Standard_B1s"
lab4_waf_mode            = "Prevention"

tags = {
  owner = "sid"
}
EOF

echo "Configured Terraform for:"
echo "  subscription:   ${subscription_id}"
echo "  tenant:         ${tenant_id}"
echo "  resource group: ${resource_group_name}"
echo "  location:       ${resource_group_location}"
