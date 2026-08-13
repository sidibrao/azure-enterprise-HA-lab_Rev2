# Rebuild in a Fresh Sandbox

The sandbox deletes Azure resources, but the Terraform configuration remains in
this local folder. Do not reuse the old `terraform.tfstate` with a different
sandbox. Archive it before initializing the fresh environment.

## 1. Log in with the new sandbox account

```bash
az logout
az account clear
az login --use-device-code
az account show -o table
```

Select the new `P4-Real Hands-On Labs` subscription during login.

## 2. Archive the expired sandbox state

Only do this after confirming the previous sandbox has expired and its resources
are gone:

```bash
timestamp=$(date +%Y%m%d-%H%M%S)
mkdir -p ".state-archive/${timestamp}"
mv terraform.tfstate* ".state-archive/${timestamp}/" 2>/dev/null || true
```

`.state-archive/` is ignored by Git because state files can contain SSH keys.

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
terraform init
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan -out=lab1.tfplan
terraform apply lab1.tfplan
```

Azure Firewall takes roughly 8–12 minutes. The web VM waits for the HTTP/80 and
HTTPS/443 Ubuntu egress rules before cloud-init installs Nginx.

## 5. Verify

```bash
terraform output
curl -i --connect-timeout 15 "$(terraform output -raw web_url)"
terraform plan
```

Expected: HTTP 200 and a final Terraform plan reporting no changes.
