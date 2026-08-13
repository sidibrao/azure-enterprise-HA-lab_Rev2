# Rev2 Section 4 — WAF and DDoS Secure Ingress

## Outcome

Replace the lab-only firewall HTTP ingress as the normal application path with a
zone-redundant Application Gateway WAF_v2 frontend. Keep Azure Firewall as the
central egress and non-web security control.

## Current status

**Planned.** No Application Gateway, WAF policy, WAF public IP, or DDoS IP
Protection resource currently exists in Terraform.

## Final request path

```text
DNS
  -> Application Gateway WAF_v2 public IP
  -> HTTPS listener and WAF policy
  -> private backend pool
     ├── Web VM Zone 1: 10.2.2.11
     └── Web VM Zone 2: 10.2.2.12
```

Application Gateway already performs Layer 7 load balancing. The Section 1
Internal Load Balancer remains a Layer 4 learning checkpoint or alternate test
path; it is not inserted behind WAF without a specific requirement.

## Terraform deliverables

- Dedicated Application Gateway subnet `10.1.3.0/24`.
- Standard zone-redundant public IP.
- Application Gateway WAF_v2 with at least two instances or autoscaling.
- Backend pool containing both private web nodes.
- HTTP `/health` probe.
- HTTP listener for initial testing.
- HTTPS listener and certificate variable for the production-style stage.
- OWASP managed rules.
- Custom block rule for header `X-Lab-Block: true`.
- WAF access/firewall/performance diagnostics to Log Analytics.
- DDoS IP Protection feature flag.
- Backend NSG allowing traffic from the Application Gateway subnet only.

## Azure resources produced

| Resource | Planned purpose |
|---|---|
| `snet-appgateway` | Dedicated `10.1.3.0/24` subnet |
| `pip-contoso-waf` | Zone-redundant public WAF frontend |
| `agw-contoso-online` | Application Gateway WAF_v2 |
| `wafp-contoso-online` | OWASP and custom WAF policy |
| Backend pool | Two private zonal web VMs |
| WAF diagnostics | Central Log Analytics tables |
| DDoS IP Protection | Optional/capability-gated public IP protection |

## Terraform outputs

```hcl
output "waf_public_ip" {}
output "waf_fqdn" {}
output "waf_http_url" {}
output "waf_https_url" {}
output "application_gateway_id" {}
output "waf_policy_id" {}
output "waf_backend_pool_id" {}
output "waf_probe_name" {}
output "ddos_protection_status" {}
output "waf_log_analytics_workspace_id" {}
```

## Validation output

- Normal request returns HTTP 200.
- `X-Lab-Block: true` request is denied.
- SQL-injection-style request triggers a managed WAF rule.
- WAF logs show rule ID, action, client, and request URI.
- Both backends are healthy.
- One backend can stop without application outage.
- Backend VMs have no public IP.
- Direct backend traffic is not exposed.
- DDoS status is either deployed/verified or explicitly marked design-only.

## Security-layer responsibility

| Control | Responsibility |
|---|---|
| DDoS Protection | Layer 3/4 volumetric protection |
| Application Gateway WAF | HTTP/HTTPS Layer 7 inspection and load balancing |
| Azure Firewall | Central egress and broader network/application filtering |
| NSG | Subnet/NIC Layer 3/4 access control |
