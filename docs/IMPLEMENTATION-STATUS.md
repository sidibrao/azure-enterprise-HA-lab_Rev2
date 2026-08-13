# Rev2 Implementation Status

## Status definitions

| Status | Meaning |
|---|---|
| Implemented | Terraform/Bicep/PowerShell exists and passes static validation |
| Azure validated | Deployed and functionally tested in an Azure sandbox |
| Planned | Architecture and output contract are documented; code is not complete |
| Capability-gated | Implementation depends on sandbox permissions, region, quota, SKU, or cost |
| Design only | Intentionally documented without deployment |

## Current dashboard

| Work item | Code | Azure | Evidence expected |
|---|---|---|---|
| Rev1 hub/spoke and firewall | Implemented | Previously validated | Forced route, allowed/blocked egress, logs |
| Rev1 ERP test VM | Implemented | Previously validated | Private IP `10.2.1.10` |
| Rev1 single web VM and DNAT | Implemented | Previously validated | HTTP 200 through firewall public IP |
| Section 1 ALZ management groups | Planned | Not deployed | Hierarchy and inheritance report |
| Section 1 Bicep diagnostics | Planned | Not deployed | Diagnostic settings listed |
| Section 1 PowerShell inheritance report | Planned | Not deployed | Policy/RBAC report artifacts |
| Section 1 zonal web VM pair | Implemented | Azure validated | Zones 1/2, `10.2.2.11-12`, healthy/failover passed |
| Section 1 internal Standard Load Balancer | Implemented | Azure validated | Frontend `10.2.2.20`, two healthy backends |
| Section 1 firewall DNAT and DNS | Implemented | Azure validated | `erp-web-yo2oo.eastus.cloudapp.azure.com` |
| Section 4 Application Gateway WAF_v2 | Implemented | Azure validated | Two healthy zonal frontend backends |
| Section 4 OWASP 3.2 managed rules | Implemented | Azure validated | SQLi-style request returned HTTP 403 |
| Section 4 custom header rule | Implemented | Azure validated | `X-Lab-Block: true` returned HTTP 403 |
| Section 4 frontend/API zonal pairs | Implemented | Azure validated | Both independent failover tests passed |
| Section 4 Azure SQL Basic/private endpoint | Implemented | Azure validated | Seed/create/read/validation tests passed |
| Section 4 public/private DNS | Implemented | Azure validated | WAF, frontend, API and SQL names resolve at intended scopes |
| Section 4 DDoS IP Protection | Capability-gated | Not deployed | Protection status or design record |
| Section 9 policy initiative | Planned | Not deployed | Deny/audit/remediation evidence |
| Section 9 RBAC groups and roles | Capability-gated | Not deployed | Scope boundary report |
| Section 9 exemptions | Planned | Not deployed | Approved exemption example |
| Section 9 drift workflow | Planned | Not configured | Scheduled/PR plan result |

## Planned Terraform file map

```text
modules/
├── alz-hierarchy/
├── hub-network/
├── spoke-network/
├── azure-firewall/
├── zonal-web-tier/
├── internal-load-balancer/
├── application-gateway-waf/
├── monitoring/
├── governance-initiative/
└── rbac/

sections/
├── rev2-section-01-alz-ha/
│   ├── terraform/
│   ├── bicep/
│   ├── powershell/
│   └── README.md
├── rev2-section-04-waf-ddos/
│   ├── terraform/
│   └── README.md
└── rev2-section-09-governance-drift/
    ├── terraform/
    ├── powershell/
    └── README.md
```

These directories are the implementation targets. They are not marked
Implemented until executable files exist and their tests pass.

## Completion rule

A section is complete only when all four conditions are met:

1. IaC is committed.
2. Static tests pass.
3. Azure deployment is attempted and its result recorded.
4. Functional validation evidence is captured.

A sandbox denial can result in **Code complete / Azure blocked**, but never in a
false claim that the resource was deployed.
