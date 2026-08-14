# Rev2 Section 2 — Online Landing Zone, WAF and Private Data

Status: **implemented and Azure validated**. The detailed build and test guide
is [Lab 2 WAF Online Runbook](../../docs/LAB4-WAF-ONLINE-RUNBOOK.md).

The directory retains `section-04` only as a historical repository path. The
sequential Rev2 curriculum calls this Lab 2/Section 2, and Terraform retains
`lab4_*` addresses to avoid state migration.

```text
Internet / public Azure DNS
  -> zone-redundant Application Gateway WAF_v2 (OWASP 3.2)
  -> frontend VM zone 1 or zone 2 (private)
  -> api.online.contoso.internal:8000
  -> internal Standard Load Balancer
  -> API VM zone 1 or zone 2 (private)
  -> Azure SQL Basic through private endpoint and private DNS
```

Azure Firewall remains the shared hub egress control. The existing Corp
Firewall-DNAT website remains available as a separate Lab 1 learning path.
DDoS Network/IP Protection remains design-only because of sandbox cost.

Validated outcomes:

- Normal portal request: HTTP 200.
- WAF custom header: HTTP 403.
- OWASP SQL-injection request: HTTP 403.
- Both Application Gateway backends healthy.
- Frontend zone failover passed.
- API zone failover passed while SQL remained connected.
- Valid record created and read from SQL; invalid record rejected with 400.
- No application VM or SQL endpoint is directly public.
