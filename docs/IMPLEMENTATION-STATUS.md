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
| Section 1 zonal web VM 1 | Planned | Not deployed | Zone 1, IP `10.2.2.11`, healthy |
| Section 1 zonal web VM 2 | Planned | Not deployed | Zone 2, IP `10.2.2.12`, healthy |
| Section 1 internal Standard Load Balancer | Planned | Not deployed | Frontend `10.2.2.20`, two healthy backends |
| Section 1 firewall DNAT to ILB | Planned | Not deployed | HTTP reaches both nodes |
| Section 4 Application Gateway WAF_v2 | Planned | Not deployed | Healthy zone-redundant gateway |
| Section 4 OWASP managed rules | Planned | Not deployed | SQLi-style request blocked/logged |
| Section 4 custom header rule | Planned | Not deployed | `X-Lab-Block: true` blocked/logged |
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
