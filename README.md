# Azure Enterprise HA Landing Zone — Rev2

Rev2 is a hands-on, cost-conscious Azure landing-zone lab with a shared hub,
central Azure Firewall, Corp and Online spokes, zonal compute, private DNS,
Application Gateway WAF_v2, and Azure SQL through a private endpoint.

Start with the [Low-Level Design and Fresh-Sandbox Deployment Guide](docs/LLD-FRESH-SANDBOX-DEPLOYMENT-GUIDE.md).
It contains the complete Portal-first build, Terraform workflow, testing,
troubleshooting, cleanup, CAF/ALZ design, policy guidance, and appendices.

> **Validated status:** Labs 0, 1, and 2 have been deployed and functionally
> validated in Azure. Lab 3 governance remains capability-gated by the training
> tenant's management-group, Policy, RBAC, and Entra permissions.

## Sequential curriculum

| Lab | Name | Outcome | Status |
|---|---|---|---|
| Lab 0 | Bootstrap and prerequisites | Azure CLI authentication, sandbox discovery, remote state, validation | Implemented and validated |
| Lab 1 | Corp ALZ and multi-zone HA | Hub/Corp spoke, Firewall, UDR, two zonal web VMs, internal LB, DNS | Implemented and validated |
| Lab 2 | Online WAF and private data | Online spoke, WAF_v2, two frontend VMs, two API VMs, API LB, private SQL | Implemented and validated |
| Lab 3 | Governance and drift control | Management-group policy, RBAC, exemptions, remediation, CI drift | Design/reference; sandbox gated |

The original source requirements called the Online lab “Lab 4” and governance
“Lab 9.” Rev2 presents them sequentially as Labs 2 and 3. Existing Terraform
identifiers such as `lab4_*` and filenames such as `lab4-network.tf` remain for
state compatibility; renaming resource addresses would require state moves and
would add risk without changing Azure architecture.

## Architecture

[![Rev2 high-availability Azure architecture](docs/diagrams/architecture-rev2.svg)](docs/diagrams/architecture-rev2.svg)

Editable source:
[architecture-rev2.excalidraw](docs/diagrams/architecture-rev2.excalidraw).

```text
Internet
├── Lab 1 DNS -> Azure Firewall public IP:80
│   -> DNAT -> Corp ILB 10.2.2.20
│      -> web zone 1 10.2.2.11 / web zone 2 10.2.2.12
└── Lab 2 DNS -> Application Gateway WAF_v2 (zones 1 and 2)
    -> frontend zone 1 10.3.1.11 / frontend zone 2 10.3.1.12
    -> API ILB 10.3.2.20:8000
       -> API zone 1 10.3.2.11 / API zone 2 10.3.2.12
       -> Azure SQL private endpoint in 10.3.3.0/24

Corp/Online outbound -> UDR 0.0.0.0/0 -> Azure Firewall 10.1.0.4
Diagnostics -> central Log Analytics workspace
```

## Current implementation status

| Component | Terraform | Azure validation |
|---|---|---|
| Remote Blob state and lease locking | Implemented | Validated |
| Hub, Firewall Basic and central diagnostics | Implemented | Validated |
| Corp and Online spokes with bidirectional peerings | Implemented | Connected/FullyInSync |
| Lab 1 zonal web pair and internal LB | Implemented | HTTP and failover validated |
| Lab 1 Firewall DNAT and DNS | Implemented | HTTP 200 validated |
| Lab 2 WAF_v2 and managed/custom rules | Implemented | Normal 200; malicious tests 403 |
| Lab 2 zonal frontend and API pairs | Implemented | Both gateway backends healthy |
| Azure SQL Basic private endpoint/DNS | Implemented | API reports database connected |
| Management groups and inherited Policy | Reference only | Blocked by sandbox scope |
| DDoS paid protection | Design only | Not deployed for lab cost |

See [Implementation Status](docs/IMPLEMENTATION-STATUS.md) for the evidence
matrix and [Lab 2 Runbook](docs/LAB2-WAF-ONLINE-RUNBOOK.md) for application and
WAF tests.

## Repository map

| Path | Purpose |
|---|---|
| `versions.tf` | Terraform/provider requirements and Azure backend declaration |
| `variables.tf` | Subscription, tenant, resource group, SKU and feature inputs |
| `main.tf` | Hub, Corp spoke, Firewall, egress, logging and ERP VM |
| `web-vm.tf`, `web-content.tf` | Lab 1 zonal web tier, ILB, DNAT and pages |
| `dns.tf` | Lab 1 public/private DNS |
| `lab4-network.tf` | Lab 2 Online network, NSGs, UDR and serialized peerings |
| `lab4-compute.tf` | Lab 2 zonal frontend/API VMs and resilient extensions |
| `lab4-database.tf` | SQL Basic, private endpoint and private DNS |
| `lab4-waf.tf`, `lab4-dns.tf` | WAF_v2 ingress, rules, diagnostics and DNS |
| `outputs.tf`, `lab4-outputs.tf` | Deployment URLs, IPs, DNS and identifiers |
| `templates/` | Nginx, API and repeatable guest configuration templates |
| `tests/` | Offline Terraform architecture contract tests |
| `bootstrap-state-backend.sh` | Creates/reuses private Azure Blob state backend |
| `configure-sandbox.sh` | Generates ignored sandbox-specific variables |
| `validate-deployment.sh` | Non-destructive end-to-end live validation |
| `policy.tf.disabled` | Enterprise governance reference excluded in restricted sandbox |

Terraform loads all top-level `.tf` files as one configuration. Never execute a
`.tf` or `.tftpl` file directly.

## Fast deployment

Use the detailed guide for a first deployment. The abbreviated workflow is:

```bash
cd "/home/sadmin/tech projects/Azure Projects/02-azure-enterprise-lab/azure-enterprise-lab_Rev2-HA-ALZ"

az logout
az account clear
az login --tenant <tenant-id> --use-device-code
az account set --subscription <subscription-id>

./configure-sandbox.sh
./bootstrap-state-backend.sh
source .backend.env

terraform init -reconfigure -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan -out=fresh-sandbox.tfplan
terraform show -no-color fresh-sandbox.tfplan | less
terraform apply fresh-sandbox.tfplan
./validate-deployment.sh
terraform plan -detailed-exitcode
```

Expected final validation includes HTTP 200 for Labs 1/2, SQL connected, both
WAF tests returning 403, healthy Application Gateway backends, and a no-drift
Terraform plan.

## Deployment options

| Option | Command | Use |
|---|---|---|
| Interactive | `terraform apply` | Quick disposable learning; review generated plan and type `yes` |
| Saved plan | `terraform plan -out=deploy.tfplan` then `terraform apply deploy.tfplan` | Recommended; applies exactly the reviewed plan |
| Recovery | New plan after correcting state/resource failure | Only for a diagnosed partial apply; never reuse the failed plan |
| Destroy | `terraform plan -destroy -out=destroy.tfplan` then apply it | Controlled cleanup before sandbox expiry |

## Validation

```bash
./validate-deployment.sh
```

The script checks VM power, both public sites, API/SQL health, custom WAF and
OWASP blocking, and Application Gateway backend health. It automatically loads
the ignored backend environment file.

Manual outputs:

```bash
terraform output -raw lab1_public_dns_url
terraform output -raw lab4_waf_url
terraform output -json lab4_private_dns
```

Avoid `terraform output -json` without an output name because the state also
contains sensitive generated credentials and private keys.

## State, secrets and cleanup

Never commit sandbox credentials, `.backend.env`, `terraform.tfvars`, state,
plans, SQL passwords, or private keys. The Azure Blob backend supplies encrypted
storage and blob-lease locking. It is created outside the workload state so that
Terraform can safely destroy the workload without deleting its own backend.

```bash
source .backend.env
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
terraform state list            # expected: no output
```

Do not delete the backend or local backend files until destruction completes.

## Documentation

- [Documentation index](docs/README.md)
- [Complete LLD and deployment guide](docs/LLD-FRESH-SANDBOX-DEPLOYMENT-GUIDE.md)
- [Lab 2 WAF/Online runbook](docs/LAB2-WAF-ONLINE-RUNBOOK.md)
- [Implementation status](docs/IMPLEMENTATION-STATUS.md)
- [Rev2 implementation plan](docs/REV2-IMPLEMENTATION-PLAN.md)
- [Sequential lab index](sections/README.md)
- [Fresh-sandbox quick rebuild](TOMORROW.md)

The appendix of the complete guide contains the legacy-to-sequential naming
map, Terraform command reference, Portal click-path checklist, expected outputs,
recovery decision tree, and evidence checklist.
