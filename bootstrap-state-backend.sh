#!/usr/bin/env bash
set -euo pipefail

backend_rg="${1:-}"
backend_location="${2:-}"

if ! az account show >/dev/null 2>&1; then
  echo "Azure CLI is not logged in. Run: az login --use-device-code"
  exit 1
fi

subscription_id=$(az account show --query id --output tsv)

if [[ -z "${backend_rg}" ]]; then
  backend_rg=$(az group list --query "[?contains(name, 'playground-sandbox')].name | [0]" --output tsv)
fi

if [[ -z "${backend_rg}" ]]; then
  echo "No sandbox resource group found. Usage: $0 <resource-group> [location]"
  exit 1
fi

if [[ -z "${backend_location}" ]]; then
  backend_location=$(az group show --name "${backend_rg}" --query location --output tsv)
fi

backend_container="tfstate"
backend_key="azure-enterprise-ha-rev2.tfstate"

if [[ -f backend.hcl ]]; then
  backend_account=$(awk -F'"' '/storage_account_name/ {print $2}' backend.hcl)
else
  unique_suffix=$(printf '%s' "${subscription_id}${backend_rg}" | sha256sum | cut -c1-10)
  backend_account="sttfha${unique_suffix}"
fi

echo "Creating or reusing Terraform state backend:"
echo "  subscription:    ${subscription_id}"
echo "  resource group:  ${backend_rg}"
echo "  location:        ${backend_location}"
echo "  storage account: ${backend_account}"
echo "  container:       ${backend_container}"
echo "  state key:       ${backend_key}"

if ! az storage account show --name "${backend_account}" --resource-group "${backend_rg}" >/dev/null 2>&1; then
  az storage account create \
    --name "${backend_account}" \
    --resource-group "${backend_rg}" \
    --location "${backend_location}" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --https-only true \
    --tags purpose=terraform-state managedBy=lab0 \
    --output none
fi

backend_access_key=$(az storage account keys list \
  --resource-group "${backend_rg}" \
  --account-name "${backend_account}" \
  --query '[0].value' \
  --output tsv)

az storage container create \
  --name "${backend_container}" \
  --account-name "${backend_account}" \
  --account-key "${backend_access_key}" \
  --public-access off \
  --output none

printf 'resource_group_name  = "%s"\nstorage_account_name = "%s"\ncontainer_name       = "%s"\nkey                  = "%s"\n' \
  "${backend_rg}" "${backend_account}" "${backend_container}" "${backend_key}" > backend.hcl

printf 'export ARM_ACCESS_KEY=%q\n' "${backend_access_key}" > .backend.env
chmod 600 .backend.env

echo
echo "Backend bootstrap complete. Run:"
echo "  source .backend.env"
echo "  terraform init -reconfigure -backend-config=backend.hcl"
echo
echo "backend.hcl and .backend.env are ignored by Git. .backend.env contains a secret."
