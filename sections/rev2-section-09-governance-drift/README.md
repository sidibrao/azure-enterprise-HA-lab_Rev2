# Rev2 Section 9 — Governance and Drift Control

## Outcome

Turn the architecture into an enterprise-controlled environment with policy,
group-based RBAC, exemptions, diagnostics, and continuous Terraform drift checks.

## Current status

**Partial reference / planned.** `policy.tf.disabled` contains an initial public-IP
guardrail reference. The complete initiative, RBAC model, exemptions, remediation,
and GitHub drift workflow are not implemented yet.

## Terraform deliverables

Policy initiative covering:

- Allowed deployment regions.
- Required standard tags.
- Deny public IP attachment to protected workload NICs.
- Require or audit diagnostic settings.
- Require private endpoints for selected PaaS services.
- Audit VNets/public IPs requiring DDoS coverage.
- Audit workload subnets without NSGs or approved route tables.
- Restrict unsupported SKUs.

RBAC deliverables:

- Platform Owner group mapping.
- Network Contributor group mapping.
- Security Reader and Security Admin mappings.
- Restricted Workload Contributor custom role.
- Break-glass operating procedure.
- Route-table write access reserved for the network team.

Drift deliverables:

- GitHub Actions format/validate/test workflow.
- Pull-request Terraform plan.
- Scheduled `terraform plan -detailed-exitcode`.
- Manual approval before apply.
- OIDC authentication design for a permanent Azure environment.
- Sandbox plan-only mode for expiring credentials.

## Azure resources produced

| Resource/artifact | Expected result |
|---|---|
| Policy initiative | `Contoso Enterprise Guardrails` |
| Policy assignments | MG/subscription scope where authorized |
| Remediation identities | For DeployIfNotExists/Modify controls |
| Custom workload role | Contributor without platform route/policy changes |
| Role assignments | Entra groups mapped to defined scopes |
| Exemption example | Owner, reason, expiry, compensating controls |
| Activity Log alerts | Route/policy/security changes |
| GitHub workflow | Plan/test/drift evidence |

## Terraform/report outputs

```hcl
output "governance_mode" {}
output "policy_initiative_id" {}
output "policy_assignment_ids" {}
output "policy_effects" {}
output "custom_role_definition_id" {}
output "rbac_assignment_ids" {}
output "remediation_identity_ids" {}
output "exemption_ids" {}
output "diagnostic_policy_ids" {}
```

PowerShell/report artifacts:

```text
artifacts/policy-inheritance.json
artifacts/policy-compliance.csv
artifacts/rbac-boundaries.csv
artifacts/policy-exemptions.csv
artifacts/drift-plan.txt
```

Artifacts containing tenant identifiers or sensitive information will not be
committed unless sanitized.

## Validation output

1. Disallowed-region resource is denied.
2. Missing required tags are denied or remediated according to configured effect.
3. Workload public-IP attachment is denied.
4. Diagnostic setting is deployed/audited.
5. Workload contributor cannot edit platform policy or route tables.
6. Network group can manage approved route tables.
7. Security reader can inspect security posture without modifying resources.
8. Exemption includes business justification and expiry.
9. Manual Portal drift produces Terraform detailed exit code `2`.
10. Reconciliation returns Terraform to exit code `0`.

## Sandbox behavior

Every control will be labeled as Deployed, Simulated, Code complete/Azure blocked,
or Design only. Subscription and tenant permission failures are expected in the
training environment and must be recorded rather than hidden.
