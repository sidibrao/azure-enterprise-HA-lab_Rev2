# Rev2 Section 1 — ALZ and Multi-Zone HA Foundation

## Outcome

Model the Azure Landing Zone hierarchy and upgrade the single web VM into a
health-probed, multi-zone web tier behind an Internal Standard Load Balancer.

## Current status

**Workload implementation Azure validated.** The root Terraform deploys two
private web VMs at `10.2.2.11` and `10.2.2.12`, an internal Standard Load
Balancer at `10.2.2.20`, Firewall DNAT, private/public DNS and central
diagnostics. Tenant-level management groups, inherited Policy, Entra groups and
PIM remain capability-gated in the restricted sandbox.

## Architecture scope

### ALZ hierarchy

```text
Tenant Root
├── Platform
│   ├── Management
│   ├── Connectivity
│   └── Identity
├── Landing Zones
│   ├── Corp
│   └── Online
├── Sandbox
└── Decommissioned
```

Full mode creates management groups, subscription associations, policies, and
group-based RBAC. Restricted sandbox mode creates a clearly labeled resource-
group simulation and produces design/report artifacts for blocked tenant actions.

### HA data path

```text
Internet
  -> Azure Firewall public IP:80
  -> DNAT to 10.2.2.20:80
  -> Internal Standard Load Balancer
     ├── Web VM 1: 10.2.2.11, Availability Zone 1
     └── Web VM 2: 10.2.2.12, Availability Zone 2
```

Both VMs remain private. Their outbound traffic follows the existing UDR to
Azure Firewall `10.1.0.4`.

## Terraform deliverables

- Flat root resources for the sandbox workload implementation.
- `policy.tf.disabled` as an explicitly undeployed tenant-governance reference.
- Two explicit zonal VM resources or a flexible VM scale set with zone spread.
- Backend pool NIC associations.
- Internal Standard Load Balancer frontend `10.2.2.20`.
- HTTP probe on `/health`.
- TCP/80 load-balancing rule.
- Firewall DNAT translated target changed from `10.2.2.10` to `10.2.2.20`.
- Node-specific Nginx pages to prove traffic distribution.
- Bicep diagnostics deployment.
- PowerShell inherited-policy/RBAC report.

## Azure resources produced

| Resource | Planned name/value |
|---|---|
| Web VM Zone 1 | `vm-contoso-lab1-web-zone1`, `10.2.2.11` |
| Web VM Zone 2 | `vm-contoso-lab1-web-zone2`, `10.2.2.12` |
| Load Balancer | `lbi-contoso-lab1-web` |
| ILB frontend | `10.2.2.20` |
| Backend pool | `bepool-web` |
| Health probe | `probe-http-health`, `/health` |
| LB rule | TCP/80 frontend to TCP/80 backend |
| Firewall DNAT | Firewall public IP:80 to `10.2.2.20:80` |

## Terraform outputs

Implemented output contract includes:

```hcl
output "resource_group_name" {}
output "web_vm_zones" {}
output "web_vm_private_ip" {}
output "internal_load_balancer_ip" {}
output "load_balancer_backend_pool_id" {}
output "load_balancer_probe_id" {}
output "ha_test_url" {}
output "lab1_public_dns_url" {}
output "lab1_private_dns" {}
output "policy_assignment_scope" {}
```

## Validation output

The section must produce evidence for:

1. Region supports zones 1 and 2.
2. Both VMs report `Succeeded` and `VM running`.
3. Load Balancer reports two healthy backends.
4. Repeated HTTP requests show both node names.
5. Stopping the Zone 1 VM does not interrupt the website.
6. Starting Zone 1 returns it to the healthy pool.
7. Neither VM has a public IP.
8. Effective `0.0.0.0/0` route points to `10.1.0.4`.
9. Policy inheritance and RBAC boundary reports are generated or their sandbox
   authorization failure is documented.

## Sandbox gates

- West US lacks Availability Zones; use West US 2, West US 3, Canada Central, or
  another permitted zonal region.
- Confirm VM SKU availability in both zones.
- Confirm Standard Load Balancer permission and quota.
- Management groups, subscription policy, Entra groups, and RBAC may remain
  code-complete but undeployed in a restricted training tenant.
