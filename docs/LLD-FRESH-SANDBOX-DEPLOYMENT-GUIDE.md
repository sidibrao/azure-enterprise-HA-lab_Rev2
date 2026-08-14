# Azure Enterprise HA Landing Zone

## Low-Level Design and Fresh-Sandbox Deployment Guide

This document is the complete learner runbook for deploying and validating Lab
0, Lab 1 and Lab 4 from a new Real Hands-On Labs sandbox. It covers a Portal-first
learning path followed by the reproducible Terraform path.

> Do not store sandbox usernames, passwords, client secrets, SQL passwords,
> Terraform state or generated SSH private keys in Git. The repository ignores
> `terraform.tfvars`, `*.tfstate*` and `*.tfplan`.

## 1. Scope and outcomes

### Lab 0 — workstation and Azure readiness

- Install/verify Azure CLI, Terraform, Git, VS Code and extensions.
- Authenticate VS Code terminal with device-code login.
- select the new subscription and discover the assigned resource group.
- Verify permissions, providers, region, zones, quotas and clean Terraform state.
- Bootstrap an encrypted Azure Blob Storage remote backend with state locking.

### Lab 1 — Corp application landing zone

- Shared hub VNet and Azure Firewall.
- Corp/ERP spoke and bidirectional peering.
- Forced egress through the firewall.
- ERP test VM without a public IP.
- Two private web VMs in availability zones 1 and 2.
- Internal Standard Load Balancer and health probe.
- Firewall DNAT to the internal load balancer.
- Public Azure DNS and private `hub.contoso.internal` / `corp.contoso.internal`.
- Central Firewall diagnostics in Log Analytics.

### Lab 4 — Online application landing zone

- Separate Online spoke `10.3.0.0/16`.
- One logical Application Gateway WAF_v2 spanning zones 1 and 2.
- Two private frontend VMs, one per zone.
- Two private API VMs, one per zone.
- Internal API Standard Load Balancer.
- Azure SQL Basic with public access disabled.
- SQL private endpoint and private DNS.
- Interactive message form that validates, inserts and reads SQL records.
- OWASP 3.2 and custom WAF protection.
- Application Gateway and WAF diagnostics in central Log Analytics.

## 2. Logical landing-zone model

The training identity cannot normally create management groups or new workload
subscriptions, so isolation is modeled with VNets, subnets, tags and scoped
resources inside the assigned resource group.

```text
Tenant
└── Sandbox subscription
    ├── Platform / Connectivity (modeled)
    │   └── Hub VNet, Firewall, Log Analytics, shared DNS
    ├── Landing Zones / Corp (modeled)
    │   └── ERP spoke and Lab 1 application
    └── Landing Zones / Online (modeled)
        └── Online spoke and Lab 4 WAF application
```

In production, Platform, Corp and Online normally use separate subscriptions
under management groups with inherited Policy and group-based RBAC.

### 2.1 CAF and Azure landing zone relationship

The Microsoft Cloud Adoption Framework (CAF) is the operating guidance: it
covers strategy, planning, readiness, adoption, governance, security, management
and continuous improvement. An Azure landing zone (ALZ) is the Azure environment
that implements the **Ready** foundation. This lab is therefore an ALZ learning
implementation informed by CAF; it is not the full Microsoft ALZ platform
deployment.

The design records a decision for each of the eight ALZ design areas:

| ALZ design area | Lab implementation | Enterprise target |
|---|---|---|
| Billing and tenant | Provider is pinned to the active sandbox tenant/subscription | Enterprise Agreement or MCA ownership, quotas and subscription vending |
| Identity and access | Interactive Azure CLI user; resource-group permission | Entra groups, workload managed identities, PIM and break-glass controls |
| Resource organization | One assigned resource group with Platform/Corp/Online modeled by resources and tags | Management groups and separate platform/application subscriptions |
| Network topology | Hub-spoke, forced egress, private workloads and private DNS | Connectivity subscription, hybrid connectivity and centralized DNS services |
| Security | Firewall, WAF, NSGs, private endpoints and no VM public IPs | Defender for Cloud, DDoS decision, security baseline and central SecOps |
| Management | Log Analytics plus Firewall/Application Gateway diagnostics | Central management subscription, alerts, automation and recovery baseline |
| Governance | Standard tags; policy code retained but disabled | Initiatives inherited from management groups, exemptions and remediation |
| Platform automation and DevOps | Terraform, tests, remote state and Git | Federated CI/CD identity, reviews, approvals, drift detection and module registry |

The Cloud Adoption Framework governs the **platform**; the Azure
Well-Architected Framework should be used separately to assess the reliability,
security, cost, operational excellence and performance of each workload.

### 2.2 Production target hierarchy

The target hierarchy is based on workload archetypes, not on Azure regions or
development stages. Availability zones remain a workload architecture choice
inside the appropriate subscription.

```text
Tenant root management group
└── Contoso (intermediate root)
    ├── Platform
    │   ├── Management       -> logging, monitoring, automation subscription
    │   ├── Connectivity     -> hub, Firewall, DNS, VPN/ExpressRoute subscription
    │   └── Identity         -> identity services subscription when required
    ├── Landing Zones
    │   ├── Corp             -> sub-erp-prod; private/hybrid workloads (Lab 1)
    │   └── Online           -> sub-portal-prod; internet-facing workloads (Lab 4)
    ├── Sandbox              -> isolated experimentation subscriptions
    └── Decommissioned       -> disabled/cancelled subscriptions pending removal
```

Recommended ownership boundaries:

| Scope | Owner | Typical controls |
|---|---|---|
| Intermediate root / Platform | Platform team | Baseline policy, allowed regions, platform RBAC |
| Connectivity | Network team | Hub, routing, DNS, Firewall and route-table changes |
| Landing Zones | Governance/Security | Workload-agnostic security and diagnostics initiative |
| Corp | Platform/Security | Private connectivity and deny workload public IPs |
| Online | Platform/Security | Approved public ingress through WAF; private backends |
| Workload subscription/RG | Application team | Contributor rights to its workload, not parent policies |

Assign roles to Entra groups at the lowest useful scope. For example, workload
teams receive Contributor in their application subscription or resource group,
while policy is assigned at a parent management group. This lets teams operate
their application without granting permission to change inherited guardrails.

### 2.3 What this sandbox can and cannot prove

The lab proves workload architecture: hub-spoke routing, private endpoints,
private DNS, zone-aware compute, load balancing, WAF enforcement and central
diagnostics. It can also demonstrate a resource-group policy if the sandbox
role permits `Microsoft.Authorization/policyAssignments/write`.

It does **not** prove subscription vending, management-group inheritance, PIM or
cross-subscription separation when the training identity has access only to the
assigned resource group. Resource groups are not substitutes for management
groups. Capture these limitations in the lab evidence instead of weakening the
target design.

Microsoft references:

- [What is an Azure landing zone?](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [ALZ design principles](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-principles)
- [Management group design](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-management-groups)
- [Platform landing zone implementation options](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/terraform-module)

## 3. Detailed architecture

```text
LAB 1 — CORP

Internet
  -> erp-web-<suffix>.<region>.cloudapp.azure.com:80
  -> Azure Firewall public IP
  -> DNAT to ILB 10.2.2.20:80
  -> web VM zone 1 (10.2.2.11) OR zone 2 (10.2.2.12)

Private VM egress
  -> UDR 0.0.0.0/0
  -> Azure Firewall 10.1.0.4
  -> allowed FQDN rule or deny/log

LAB 4 — ONLINE

Internet
  -> contoso-portal-<suffix>.<region>.cloudapp.azure.com:80
  -> Application Gateway WAF_v2 instances across zones 1 and 2
  -> frontend VM zone 1 (10.3.1.11) OR zone 2 (10.3.1.12)
  -> api.online.contoso.internal:8000
  -> internal API LB 10.3.2.20
  -> API VM zone 1 (10.3.2.11) OR zone 2 (10.3.2.12)
  -> sql-<suffix>.database.windows.net
  -> SQL private endpoint (normally 10.3.3.4)
  -> Azure SQL Basic
```

Application Gateway is already the frontend Layer 7 load balancer. A second
frontend load balancer would duplicate that function. The internal load balancer
exists because the API is a separate private tier.

## 4. Address and DNS plan

| Component | Address |
|---|---:|
| Hub VNet | `10.1.0.0/16` |
| Azure Firewall | `10.1.0.4` |
| Corp VNet | `10.2.0.0/16` |
| ERP VM | `10.2.1.10` |
| Lab 1 web nodes | `10.2.2.11`, `10.2.2.12` |
| Lab 1 internal LB | `10.2.2.20` |
| Online VNet | `10.3.0.0/16` |
| App Gateway subnet | `10.3.0.0/24` |
| Frontend subnet/nodes | `10.3.1.0/24`; `.11`, `.12` |
| API subnet/nodes/LB | `10.3.2.0/24`; `.11`, `.12`, `.20` |
| Private endpoint subnet | `10.3.3.0/24` |

Public DNS labels contain Terraform's random suffix, so use `terraform output`
instead of assuming the previous sandbox's hostname.

| Private DNS name | Target |
|---|---:|
| `firewall.hub.contoso.internal` | `10.1.0.4` |
| `web.corp.contoso.internal` | `10.2.2.20` |
| `web-zone1/2.corp.contoso.internal` | `10.2.2.11/12` |
| `frontend.online.contoso.internal` | `10.3.1.11/12` |
| `fe-zone1/2.online.contoso.internal` | `10.3.1.11/12` |
| `api.online.contoso.internal` | `10.3.2.20` |
| `api-zone1/2.online.contoso.internal` | `10.3.2.11/12` |

SQL uses `privatelink.database.windows.net`; application code keeps using the
normal `*.database.windows.net` hostname, which resolves privately inside Online.

## 5. Prerequisites

### Local tools

```bash
az version
terraform version
git --version
code --version
```

Recommended VS Code extensions:

- HashiCorp Terraform
- Azure Resources
- Azure CLI Tools
- GitHub Pull Requests and Issues (optional)

The Azure Resources extension is convenient, but Terraform authentication uses
the Azure CLI session in the integrated terminal.

### Azure access

- New sandbox must be running and not near expiration.
- Use the assigned interactive user account.
- Client ID/secret is not required for `az login --use-device-code`.
- Identity must read/write the assigned sandbox resource group.
- Providers: Network, Compute, OperationalInsights, Insights, SQL.
- Region must support availability zones and WAF_v2.
- Allow 20–30 minutes for full deployment.

### Cost warning

Azure Firewall and Application Gateway WAF_v2 are the major hourly costs. SQL
Basic and B1s VMs are selected to minimize the remaining cost. Destroy promptly
if the sandbox does not clean itself.

## 6. Lab 0 — connect VS Code to a new sandbox

Open the repository folder in VS Code:

```bash
cd "/home/sadmin/tech projects/Azure Projects/02-azure-enterprise-lab/azure-enterprise-lab_Rev2-HA-ALZ"
code .
```

From **Terminal → New Terminal**:

```bash
az logout
az account clear
az login --tenant <tenant-id> --use-device-code
```

Open the displayed Microsoft URL, enter the device code, sign in with the new
sandbox username/password and choose its subscription. Never paste the password
into a shell command or Terraform file.

Verify and pin the subscription:

```bash
az account list -o table
az account set --subscription <subscription-id>
az account show -o table
```

Discover the assigned resource group:

```bash
az group list -o table
```

Test actual access using the real name, never the literal placeholder:

```bash
az group show --name <sandbox-resource-group> -o table
```

Register/check providers when permitted:

```bash
for provider in Microsoft.Network Microsoft.Compute Microsoft.OperationalInsights Microsoft.Insights Microsoft.Sql; do
  az provider register --namespace "$provider" --wait
done
```

Check zones/quota:

```bash
az vm list-skus --location <region> --resource-type virtualMachines --all \
  --query "[?name=='Standard_B1s'].{sku:name,zones:locationInfo[0].zones,restrictions:restrictions}" -o json

az vm list-usage --location <region> -o table
az network list-usages --location <region> -o table
```

Configure sandbox-specific, ignored variables automatically:

```bash
chmod +x configure-sandbox.sh
./configure-sandbox.sh
sed -n '1,80p' terraform.tfvars
```

Confirm `subscription_id`, `tenant_id`, resource-group name and location match
the new sandbox. The generated file enables Lab 4 by default.

### State rule for a new sandbox

Local Terraform state belongs to the previous sandbox. Archive it before a new
deployment; do not delete it blindly:

```bash
archive_dir=".state-archive/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$archive_dir"
for state_file in terraform.tfstate terraform.tfstate.backup; do
  if [ -f "$state_file" ]; then mv "$state_file" "$archive_dir/"; fi
done
```

If this repository was freshly cloned, there is no old state to archive.

### Bootstrap the remote Terraform backend

Azure Blob Storage is the Azure equivalent of an AWS S3 Terraform backend:

| AWS pattern | Azure pattern |
|---|---|
| S3 bucket | Storage Account plus private blob container |
| S3 object key | Blob name (`key`) |
| DynamoDB lock table | Azure Blob lease; no separate lock database required |
| SSE encryption | Storage Service Encryption, enabled by default |

The backend must exist before the main Terraform configuration can use it. Lab 0
therefore creates it with Azure CLI, independently of the application state:

```bash
chmod +x bootstrap-state-backend.sh
./bootstrap-state-backend.sh
source .backend.env
terraform init -reconfigure -backend-config=backend.hcl
```

The script automatically discovers the active sandbox resource group and region,
then creates or reuses:

- A globally unique StorageV2 account using Standard LRS.
- A private `tfstate` blob container.
- Blob `azure-enterprise-ha-rev2.tfstate`.
- TLS 1.2 minimum, HTTPS-only traffic and disabled public blob access.

It writes two ignored local files:

- `backend.hcl`: non-secret backend coordinates.
- `.backend.env`: Storage Account access key exported as `ARM_ACCESS_KEY`.

Never commit `.backend.env`. Source it again in a new terminal before Terraform
commands. Verify the remote state after the first apply:

```bash
source .backend.env
az storage blob list \
  --account-name "$(awk -F'"' '/storage_account_name/ {print $2}' backend.hcl)" \
  --container-name tfstate \
  --account-key "$ARM_ACCESS_KEY" \
  --query '[].{Name:name,Bytes:properties.contentLength}' -o table
```

#### Persistence warning

If the Storage Account is created inside `*-playground-sandbox`, the remote state
is locked and shared during that sandbox session, but sandbox cleanup deletes it.
To retain state across new sandboxes, supply a persistent resource group from a
subscription you control:

```bash
./bootstrap-state-backend.sh <persistent-state-resource-group> <region>
```

The sandbox identity must have access to that persistent Storage Account. A new
disposable subscription cannot use yesterday's remote state to manage resources
that no longer exist; normally use a new state key/backend for each sandbox.

#### Existing local state versus a new sandbox

For a brand-new sandbox, archive yesterday's local state as shown above and use:

```bash
terraform init -reconfigure -backend-config=backend.hcl
```

To migrate a still-valid current environment from local state into Blob Storage,
do not archive it. Bootstrap the backend and run:

```bash
source .backend.env
terraform init -migrate-state -backend-config=backend.hcl
```

Read the migration prompt carefully and answer `yes` only when the local state
belongs to the same live subscription and resources.

## 7. Portal-first deployment walkthrough

Build this manually for learning only in a fresh disposable sandbox. Use the
same names and addresses as Terraform, but do not subsequently run Terraform
against those unmanaged resources unless you import them; duplicate names will
fail. The clean learning sequence is: manual build → inspect/test → delete it →
Terraform build.

### Lab 1 in Portal

1. **Virtual networks:** create hub `10.1.0.0/16` and Corp `10.2.0.0/16`.
2. Add `AzureFirewallSubnet 10.1.0.0/26`,
   `AzureFirewallManagementSubnet 10.1.1.0/26`, ERP `10.2.1.0/24`, and web
   `10.2.2.0/24`.
3. Create bidirectional hub/Corp peerings with forwarded traffic enabled.
4. Create two Standard static Firewall public IPs and Azure Firewall Basic at
   private IP `10.1.0.4`.
5. Create a firewall policy allowing required Ubuntu HTTP/HTTPS repositories.
6. Create a route table with `0.0.0.0/0 → Virtual appliance 10.1.0.4`; associate
   it with ERP and web subnets.
7. Create ERP VM `10.2.1.10` with no public IP.
8. Create web VMs `10.2.2.11` zone 1 and `10.2.2.12` zone 2, no public IP.
9. Create Standard internal LB `10.2.2.20`, backend pool with both NICs, HTTP
   `/health` probe and TCP 80 rule.
10. Create Firewall DNAT: public IP port 80 → `10.2.2.20:80`.
11. Set the Firewall public IP DNS label.
12. Create/link private zones `hub.contoso.internal` and
    `corp.contoso.internal`, then add the records in section 4.
13. Send Firewall logs/metrics to Log Analytics.

### Lab 4 in Portal

1. Create Online VNet `10.3.0.0/16` and the four subnets in section 4.
2. Peer Hub and Online in both directions.
3. Create a default UDR to `10.1.0.4`; associate frontend/API subnets.
4. Create frontend NSG allowing TCP 80 from `10.3.0.0/24` and API NSG allowing
   TCP 8000 from `10.3.1.0/24` plus AzureLoadBalancer probes.
5. Create frontend and API Ubuntu B1s VMs in zones 1 and 2 without public IPs.
6. Create internal Standard LB `10.3.2.20`, API pool, port 8000 rule and
   `/health` probe.
7. Create/link `online.contoso.internal` and its A records.
8. Create SQL logical server and a **Basic 2 GB** database; disable public
   network access.
9. Create SQL private endpoint in `10.3.3.0/24`, private zone
   `privatelink.database.windows.net`, a zone group and VNet link.
10. Create a Standard static zone-redundant public IP and Azure DNS label.
11. Create WAF policy: Prevention, OWASP 3.2, custom rule blocking request header
    `X-Lab-Block` equal to `true`.
12. Create WAF_v2 Application Gateway in zones 1 and 2, fixed capacity 2,
    frontend listener port 80, backend IPs `.11/.12`, `/health` probe and rule.
13. Send Application Gateway logs/metrics to central Log Analytics.
14. Use VM **Run command** or extensions to install the supplied Nginx frontend
    and Flask API templates. Terraform automates this guest configuration.

## 8. Terraform deployment from scratch

Never run only `main.tf`; Terraform loads every `.tf` file in the current folder
as one configuration. Files are separated only for human organization.

```bash
source .backend.env
terraform init -reconfigure -backend-config=backend.hcl -upgrade
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan -out=fresh-sandbox.tfplan
terraform show -no-color fresh-sandbox.tfplan | less
```

Confirm the plan contains only the new sandbox resource group and no unexpected
destroy/replacement action. Then:

```bash
terraform apply fresh-sandbox.tfplan
terraform output
terraform plan -detailed-exitcode
```

Exit code 0 from the last command means no drift. Store the URLs dynamically:

```bash
LAB1_URL=$(terraform output -raw lab1_public_dns_url)
LAB4_URL=$(terraform output -raw lab4_waf_url)
echo "$LAB1_URL"
echo "$LAB4_URL"
```

## 8A. Add and apply landing-zone policy

### Policy inheritance model

Azure Policy assignments flow downward through the Azure scope hierarchy:

```text
Management group assignment
  -> child management groups
    -> subscriptions
      -> resource groups
        -> resources
```

Definitions describe a rule, initiatives group related definitions, and
assignments apply a definition or initiative at a scope. An exemption is a
reviewed exception; `notScopes` merely excludes a child scope from evaluation.
For `modify` and `deployIfNotExists`, the assignment also needs a managed
identity, suitable RBAC, and a remediation task for existing resources. A new
assignment can take several minutes to evaluate.

### Safe rollout order

1. Define the control objective and owner; prefer Microsoft built-ins where they
   express the requirement correctly.
2. Assign in `audit`, `auditIfNotExists`, or non-enforcing mode first.
3. Review compliance results and false positives across Corp and Online.
4. Remediate existing resources and document time-bound exemptions.
5. Change preventive controls to `deny` only after testing them in Sandbox.
6. Store definitions, initiatives, assignments and exemptions in Terraform;
   require pull-request review and run scheduled drift plans.

Do not assign a blanket **deny public IP** policy to this entire training
resource group. The Azure Firewall and Application Gateway are approved ingress
edges and require public IP resources. In the production hierarchy, assign that
guardrail to **Corp workload subscriptions** while keeping platform connectivity
and approved Online ingress at different scopes. If forced to use one resource
group, use a narrowly tested policy condition or a formal exemption for the edge
resources; never use an undocumented broad exclusion.

### Portal procedure

1. Open **Policy → Definitions** and review the built-in definition or
   initiative before assigning it.
2. Open **Policy → Assignments → Assign policy/initiative**.
3. Choose the narrowest test scope available. In this sandbox that is the
   assigned resource group; in the target ALZ choose `Contoso`, `Landing Zones`,
   `Corp`, or `Online` according to the control matrix below.
4. Set exclusions only when the design requires them; do not exclude the whole
   workload subscription.
5. Configure parameters such as `eastus`, required tag names, or allowed SKUs.
6. For the first test, use a non-enforcing/audit assignment where supported.
7. Create the assignment, wait for evaluation, then inspect **Policy →
   Compliance**.
8. For `modify`/`deployIfNotExists`, configure the assignment identity and role,
   then create a remediation task.
9. Attempt a compliant and a noncompliant deployment and retain both results as
   evidence.

### Recommended assignment matrix

| Scope | Initial effect | Example controls |
|---|---|---|
| Contoso intermediate root | Audit | security baseline visibility; keep root assignments few |
| Platform | Audit/Deny after validation | required diagnostics, approved regions, platform tags |
| Landing Zones | Audit then Deny/Modify | allowed regions, required tags, diagnostic baseline |
| Corp | Deny | NIC public IPs; approved private connectivity and route controls |
| Online | Audit/Deny with approved edge pattern | private backends; public ingress only through WAF |
| Sandbox | Audit | cost, regions and security visibility without blocking exploration |
| Decommissioned | Deny | deny deployments/changes except approved cleanup operations |

### Terraform paths in this repository

`policy.tf.disabled` is deliberately excluded because Terraform only loads files
ending in `.tf`, and the restricted sandbox normally lacks subscription or
management-group policy permissions. It is a learning reference, not a file to
rename blindly: its subscription-wide deny would conflict with the public edge
resources used by this combined lab.

Use one of these implementation paths:

**Restricted sandbox:** create a separate optional resource-group policy file
containing only a harmless audit control, after the permission check below.

```bash
RG_ID=$(az group show -n <sandbox-resource-group> --query id -o tsv)
az role assignment list --scope "$RG_ID" --include-inherited -o table
az policy assignment list --scope "$RG_ID" -o table
```

If either policy command returns `AuthorizationFailed`, leave policy disabled
and document the limitation. ARM, Bicep and Portal use the same Azure RBAC
authorization and cannot bypass it.

**Enterprise tenant:** deploy the management-group hierarchy and policy in a
separate platform-bootstrap/root module using a privileged pipeline identity.
Keep the workload stack in this folder on a lower-privileged identity. The
normal sequence is:

```text
1. Tenant/platform bootstrap -> management groups and platform subscriptions
2. Policy library            -> definitions and initiatives
3. Policy assignments        -> management-group scopes and exemptions
4. Subscription vending      -> place Corp/Online subscriptions in hierarchy
5. Workload deployment       -> this Lab 1/Lab 4 stack
6. Compliance validation     -> query effective assignments and test controls
```

For a production ALZ, prefer the Microsoft ALZ IaC Accelerator and Azure
Verified Modules rather than growing this teaching stack into a tenant-scale
platform implementation.

Policy references:

- [Azure Policy overview](https://learn.microsoft.com/azure/governance/policy/overview)
- [Evaluate the impact of a new policy](https://learn.microsoft.com/azure/governance/policy/concepts/evaluate-impact)
- [Remediate noncompliant resources](https://learn.microsoft.com/azure/governance/policy/how-to/remediate-resources)

### Validate effective policy

List assignments visible at the resource group, including inherited ones:

```bash
RG_ID=$(az group show -n <sandbox-resource-group> --query id -o tsv)
az policy assignment list --scope "$RG_ID" --disable-scope-strict-match -o table
az policy state summarize --resource-group <sandbox-resource-group> -o json
```

In a tenant where the subscription is under `Corp`, validate the hierarchy and
effective assignments:

```bash
az account management-group subscription show-sub-under-mg \
  --name <corp-management-group-id> --subscription <subscription-id>
az policy assignment list --scope /subscriptions/<subscription-id> \
  --disable-scope-strict-match -o table
```

Test deny behavior with a disposable noncompliant resource, then delete it if it
was unexpectedly allowed. A denial should name the policy assignment in the ARM
error. Also confirm a compliant private NIC/VM still deploys successfully; a
negative test alone is not sufficient validation.

## 9. Functional testing

### Lab 1

```bash
curl -i "$LAB1_URL"
for i in $(seq 1 10); do curl -s "$LAB1_URL" | grep -o 'Zone [12]'; done
```

Private DNS test from a Corp or linked VNet VM:

```bash
getent hosts firewall.hub.contoso.internal
getent hosts web.corp.contoso.internal
getent hosts web-zone1.corp.contoso.internal
getent hosts web-zone2.corp.contoso.internal
```

### Lab 4 browser/database

Open `$LAB4_URL`, enter a 2–60 character safe name and a 3–240 character
message, then select **Validate & save to SQL**. The new record appears in the
table and shows the API zone that served it.

CLI equivalent:

```bash
curl "$LAB4_URL/api/health"
curl -X POST -H 'Content-Type: application/json' \
  --data '{"name":"Sid","message":"Fresh sandbox database test"}' \
  "$LAB4_URL/api/messages"
curl "$LAB4_URL/api/messages"
```

Input validation:

```bash
curl -i -X POST -H 'Content-Type: application/json' \
  --data '{"name":"!","message":"x"}' "$LAB4_URL/api/messages"
```

Expected: HTTP 400.

### WAF

```bash
curl -o /dev/null -w '%{http_code}\n' -H 'X-Lab-Block: true' "$LAB4_URL/"
curl -o /dev/null -w '%{http_code}\n' "$LAB4_URL/?id=%27%20OR%201%3D1--"
```

Expected: 403 for both. Normal `/` is 200.

Backend health:

```bash
az network application-gateway show-backend-health \
  -g <sandbox-resource-group> -n agw-contoso-online \
  --query 'backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}' -o table
```

## 10. HA failover tests

Stopping Nginx/API is reversible and proves health-probe behavior. Always restore
the service after each test.

### Lab 1 web failover

```bash
az vm run-command invoke -g <sandbox-resource-group> \
  -n vm-contoso-lab1-web-zone1 --command-id RunShellScript \
  --scripts 'systemctl stop nginx'
sleep 15
curl "$LAB1_URL"                 # page must show zone 2
az vm run-command invoke -g <sandbox-resource-group> \
  -n vm-contoso-lab1-web-zone1 --command-id RunShellScript \
  --scripts 'systemctl start nginx; systemctl is-active nginx'
```

### Lab 4 API failover

```bash
az vm run-command invoke -g <sandbox-resource-group> \
  -n vm-contoso-online-api-zone1 --command-id RunShellScript \
  --scripts 'systemctl stop contoso-api'
sleep 12
curl "$LAB4_URL/api/health"      # api_zone must be 2, DB connected
az vm run-command invoke -g <sandbox-resource-group> \
  -n vm-contoso-online-api-zone1 --command-id RunShellScript \
  --scripts 'systemctl start contoso-api; systemctl is-active contoso-api'
```

### Lab 4 frontend failover

```bash
az vm run-command invoke -g <sandbox-resource-group> \
  -n vm-contoso-online-fe-zone1 --command-id RunShellScript \
  --scripts 'systemctl stop nginx'
sleep 35
curl "$LAB4_URL" | grep 'Zone 2'
az vm run-command invoke -g <sandbox-resource-group> \
  -n vm-contoso-online-fe-zone1 --command-id RunShellScript \
  --scripts 'systemctl start nginx; systemctl is-active nginx'
```

## 11. Logs and evidence

Portal: **Log Analytics workspace → Logs**.

```kusto
AzureDiagnostics
| where Category == "ApplicationGatewayFirewallLog"
| project TimeGenerated, clientIp_s, requestUri_s, ruleId_s, action_s, message_s
| order by TimeGenerated desc
```

Capture these as evidence:

- Terraform apply summary and no-drift plan.
- Both WAF backends Healthy.
- Normal 200, custom-rule 403 and OWASP 403.
- Database create/read response and invalid-input 400.
- Lab 1, frontend and API failover outputs.
- Private DNS resolutions and proof that application VMs have no public IP.

## 12. Troubleshooting

| Symptom | Check |
|---|---|
| AuthorizationFailed | Correct subscription/RG; sandbox role assignment; relogin |
| Terraform points to yesterday | Archive old state and rerun `configure-sandbox.sh` |
| WAF 502 | Application Gateway backend health, Nginx, NSG, `/health` |
| API timeout | API LB backend pool/probe, NSG, `systemctl status contoso-api` |
| DB unavailable | SQL private DNS resolution, endpoint approval, port 1433 |
| Same zone repeatedly | Flow hashing/connection reuse; use failure test, not refresh count |
| Private DNS fails locally | Expected; test from a linked VNet VM |
| Run Command unavailable | Sandbox restriction/region; inspect VM agent or use extensions |

Useful guest checks:

```bash
systemctl status nginx --no-pager
systemctl status contoso-api --no-pager
journalctl -u contoso-api -n 80 --no-pager
getent hosts api.online.contoso.internal
getent hosts <sql-server>.database.windows.net
```

## 13. Destroy and rebuild

Review before destruction:

```bash
terraform plan -destroy -out=destroy.tfplan
terraform show -no-color destroy.tfplan | less
terraform apply destroy.tfplan
```

For the next sandbox: authenticate, select subscription, run
`configure-sandbox.sh`, archive old state, initialize, validate/test, plan and
apply. DNS labels and public IPs will change; always obtain them from outputs.

## 14. Production improvements

- Separate Platform, Corp and Online subscriptions under ALZ management groups.
- Group-based RBAC, PIM, break-glass process and management-group Policy.
- HTTPS-only WAF listener, Key Vault certificate and HTTP redirect.
- Managed identity and Key Vault instead of SQL credentials in Terraform state.
- Zone-redundant vCore SQL tier instead of Basic.
- DDoS Network Protection/IP Protection where justified.
- Remote encrypted Terraform state with locking and CI drift detection.
- Azure Monitor alerts, Defender for Cloud and Sentinel analytics.
