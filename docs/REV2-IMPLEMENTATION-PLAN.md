# Rev2 Implementation Plan

## Objective

Extend the proven Rev1 hub-and-spoke lab into an enterprise-style platform that
combines:

- Lab 1: Azure Landing Zone skeleton.
- Multi-zone application high availability.
- Lab 4: WAF and DDoS protection.
- Lab 9: Governance, RBAC, policy, and drift control.

Rev1 remains unchanged in its own repository. Rev2 is developed here and released
in capability-gated stages because training sandboxes commonly restrict tenant,
subscription, region, SKU, quota, and RBAC operations.

## Architecture decisions

### Availability, not regional disaster recovery

Two backend VMs will run in separate Availability Zones within one region. This
provides zone-level high availability. Multi-region disaster recovery is a future
phase and must include a second region, replicated application/data state, global
routing, recovery objectives, and tested failover.

West US doesn't provide Availability Zones. Preferred regions, subject to sandbox
policy and quota, are:

1. West US 2
2. West US 3
3. Canada Central
4. East US 2

The pre-created resource group's metadata location doesn't prevent its resources
from using another allowed Azure region.

### Web ingress and firewall placement

Final HTTP(S) design:

```text
DNS
  -> Application Gateway WAF_v2 public frontend
  -> two private web backends across zones

Web/ERP egress
  -> UDR 0.0.0.0/0
  -> Azure Firewall
  -> approved destinations
```

Application Gateway WAF_v2 is itself a Layer 7 load balancer. Azure Firewall does
not contain a WAF. The two services operate in parallel:

- WAF: HTTP headers/body, OWASP and custom Layer 7 rules.
- Firewall: centralized network/application egress and non-web DNAT.
- NSG: subnet and NIC Layer 3/4 rules.
- DDoS: Layer 3/4 volumetric protection for supported public IPs.

### Standard Load Balancer learning stage

Before adding WAF, Rev2 will demonstrate Layer 4 availability:

```text
Firewall public IP:80
  -> DNAT
  -> Internal Standard Load Balancer 10.2.2.20:80
  -> Web VM 1 10.2.2.11 (Zone 1)
  -> Web VM 2 10.2.2.12 (Zone 2)
```

Once Application Gateway WAF is deployed, the WAF becomes the normal web ingress
and distributes directly to both web VMs. The firewall-to-ILB path can remain on
an alternate lab-only port or be disabled to avoid two load balancers in the same
production request path.

## Proposed address plan

| Component | Address |
|---|---|
| Hub VNet | `10.1.0.0/16` |
| Azure Firewall subnet | `10.1.0.0/26` |
| Azure Firewall | `10.1.0.4` |
| Firewall management subnet | `10.1.1.0/26` |
| Application Gateway subnet | `10.1.3.0/24` |
| ERP/Online spoke | `10.2.0.0/16` |
| ERP subnet | `10.2.1.0/24` |
| Web subnet | `10.2.2.0/24` |
| Web VM Zone 1 | `10.2.2.11` |
| Web VM Zone 2 | `10.2.2.12` |
| Internal Load Balancer | `10.2.2.20` |
| Workload default route | `0.0.0.0/0 -> 10.1.0.4` |

## Rev2 Section 1 — ALZ and Multi-Zone HA Foundation

### Full tenant mode

Terraform will model:

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

Deliverables:

- Terraform management groups, subscription associations, policies, and RBAC.
- Bicep resource groups and diagnostic settings.
- PowerShell inherited-policy and RBAC-scope reports.
- Standard tag vocabulary and naming convention.
- Group-based roles for platform, network, security, workload, and break-glass.

### Restricted sandbox mode

If tenant operations are denied, Rev2 will deploy a resource-group-scoped
simulation while retaining full tenant Terraform behind feature flags:

```hcl
deployment_mode          = "sandbox"
enable_tenant_governance = false
```

The sandbox mode validates organization, tags, diagnostics, routing, and workload
boundaries without pretending that management groups were actually deployed.

### High-availability web tier and Internal Standard Load Balancer

Build:

- Two identical private Ubuntu/Nginx VMs.
- Explicit zones `1` and `2` when supported.
- Standard internal Load Balancer with zone-redundant frontend.
- HTTP `/health` probe and backend pool.
- Node-specific response content to prove distribution.
- No backend public IPs.
- UDR through Azure Firewall for package installation and egress.

Validation:

1. Confirm both backends healthy.
2. Send repeated requests and observe both node identifiers.
3. Stop the Zone 1 VM.
4. Confirm uninterrupted service from Zone 2.
5. Restart Zone 1 and confirm health recovery.

## Rev2 Section 4 — WAF and DDoS Secure Ingress

Build:

- Application Gateway WAF_v2 in a dedicated subnet.
- Zone-redundant gateway where the region supports zones.
- Public frontend and private backend pool.
- OWASP managed rules.
- Custom block rule for `X-Lab-Block: true`.
- Health probe `/health`.
- Access, performance, and firewall diagnostics in Log Analytics.
- DDoS IP Protection feature flag when sandbox budget and permissions permit.
- Documented DDoS design and policy when deployment is blocked.

Validation:

```bash
curl -i http://<waf-ip>/
curl -i -H 'X-Lab-Block: true' http://<waf-ip>/
curl -i 'http://<waf-ip>/?id=%27%20OR%201=1--'
```

Confirm allowed traffic, blocked test traffic, WAF logs, and absence of direct
backend public access.

## Rev2 Section 9 — Governance and Drift Control

Policy initiative:

- Allowed regions.
- Required tags.
- Deny workload NIC public IPs.
- Require/audit diagnostic settings.
- Require private endpoints for selected PaaS services.
- Audit DDoS coverage.
- Audit subnet NSGs and forced-routing associations.
- Restrict unsupported SKUs.

Effects mature through:

```text
Disabled -> Audit -> Remediation -> Deny
```

RBAC design:

| Group | Intended scope | Role |
|---|---|---|
| Platform owners | Platform MG/subscription | Owner via PIM |
| Network contributors | Connectivity scope | Network Contributor |
| Security readers | Enterprise scope | Security Reader |
| Security admins | Security resources | Security Admin |
| Workload contributors | Corp/Online workload | Restricted Contributor |
| Break-glass | Emergency only | Documented and monitored |

Drift control:

- Terraform format, validation, and tests.
- Pull-request Terraform plan.
- `terraform plan -detailed-exitcode` drift detection.
- Manual approval before apply.
- GitHub OIDC in a permanent account; no stored client secrets.
- Sandbox-safe plan-only workflow when credentials are ephemeral.

## Repository refactor

Rev2 will evolve from the flat Rev1 root into:

```text
modules/
├── hub-network/
├── spoke-network/
├── firewall/
├── zonal-web-vms/
├── internal-load-balancer/
├── application-gateway-waf/
├── monitoring/
├── governance/
└── rbac/

labs/
├── lab-01-alz-skeleton/
├── lab-04-waf-ddos/
└── lab-09-governance-drift/
```

## Fresh sandbox sequence

1. Authenticate with the new sandbox account.
2. Discover subscription, tenant, resource group, and allowed region.
3. Check zone/SKU/quota support before planning.
4. Generate ignored environment variables.
5. Initialize, validate, and test.
6. Deploy the Rev1 baseline in Rev2.
7. Add/refactor the HA stage.
8. Validate zone failover.
9. Add WAF and validate blocking/logging.
10. Add deployable governance permitted by the sandbox.
11. Document every permission-gated control.
12. Confirm a zero-drift plan and publish evidence.

## Sandbox capability gates

No design component is silently omitted. Each feature will be classified as:

- **Deployed** — created and validated in Azure.
- **Simulated** — resource-group equivalent used due to tenant restrictions.
- **Code complete** — IaC exists but sandbox authorization prevents apply.
- **Design only** — blocked by cost, quota, SKU, or unsupported region.

This keeps the lab honest while preserving production-quality architecture.
