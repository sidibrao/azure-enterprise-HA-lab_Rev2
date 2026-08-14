# Rebuild in a Fresh Sandbox

The sandbox deletes Azure resources, but the Terraform configuration remains in
this local folder. Each replacement sandbox needs new Azure CLI authentication,
variables and normally a new disposable Blob backend/state key.

## 1. Log in with the new sandbox account

```bash
az logout
az account clear
az login --use-device-code
az account show -o table
```

Select the newly assigned Hands-On Labs subscription during login and verify its
ID; never assume yesterday's `P4`, `P5`, or `P6` subscription.

## 2. Separate the expired sandbox state

Local state is used only by older revisions. If it exists, archive it after
confirming the previous resources are gone:

```bash
timestamp=$(date +%Y%m%d-%H%M%S)
mkdir -p ".state-archive/${timestamp}"
mv terraform.tfstate* ".state-archive/${timestamp}/" 2>/dev/null || true
```

`.state-archive/` is ignored by Git because state files can contain SSH keys.
Do not point a new sandbox at a remote state that still owns live resources in a
different subscription.

## 3. Discover the new Azure IDs

```bash
chmod +x configure-sandbox.sh
./configure-sandbox.sh
```

This reads the active Azure CLI session and writes the new subscription ID,
tenant ID, resource-group name, and location into ignored `terraform.tfvars`.
It never stores the username, password, application secret, or client secret.

## 4. Validate and deploy

```bash
chmod +x bootstrap-state-backend.sh
./bootstrap-state-backend.sh
source .backend.env
terraform init -reconfigure -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan -out=fresh-sandbox.tfplan
terraform show -no-color fresh-sandbox.tfplan | less
terraform apply fresh-sandbox.tfplan
```

Azure Firewall and Application Gateway are the slowest resources. Lab 2 guest
extensions run only after both Hub/Online peerings exist and verify Nginx,
API/private DNS and SQL health before Terraform succeeds.

## 5. Verify

```bash
./validate-deployment.sh
terraform output -raw lab1_public_dns_url
terraform output -raw lab4_waf_url
terraform plan -detailed-exitcode
```

Expected: both sites HTTP 200, SQL connected, WAF tests 403, healthy gateway
backends, and detailed exit code 0.
