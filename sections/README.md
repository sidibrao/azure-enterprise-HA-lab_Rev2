# Rev2 Sequential Labs

| Lab | Section | Result |
|---|---|---|
| Lab 0 | Bootstrap prerequisites | Authenticate, discover the sandbox resource group, and create remote state |
| Lab 1 | [Corp ALZ and multi-zone HA](rev2-section-01-alz-ha/README.md) | Hub/Corp networking, Firewall, private zonal web tier, load balancing, and DNS |
| Lab 2 | [Online WAF and private data](rev2-section-02-waf-private-data/README.md) | WAF_v2, zonal frontend/API tiers, private SQL, DNS, and security validation |
| Lab 3 | [Governance and drift control](rev2-section-03-governance-drift/README.md) | Policy, RBAC, exemptions, remediation, and continuous drift design |

The deployable Terraform is intentionally kept in the repository root. Run
Terraform from the root directory; do not run it from an individual section.
