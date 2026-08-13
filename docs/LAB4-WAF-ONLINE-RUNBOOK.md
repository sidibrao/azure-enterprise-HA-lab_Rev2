# Lab 4 WAF Online Landing Zone Runbook

## Deployed design

```text
Corp landing zone (10.2.0.0/16)
  Internet -> Azure Firewall public DNS/IP -> DNAT -> ILB 10.2.2.20
    -> web zone1 10.2.2.11 / web zone2 10.2.2.12

Shared hub (10.1.0.0/16)
  Azure Firewall 10.1.0.4 + central Log Analytics

Online landing zone (10.3.0.0/16)
  Internet -> WAF public DNS/IP -> Application Gateway WAF_v2 (zones 1,2)
    -> frontend zone1 10.3.1.11 / frontend zone2 10.3.1.12
    -> api.online.contoso.internal -> ILB 10.3.2.20:8000
    -> API zone1 10.3.2.11 / API zone2 10.3.2.12
    -> SQL private endpoint 10.3.3.4
```

Application Gateway is the frontend Layer 7 load balancer; no extra frontend
load balancer is required. The internal load balancer independently distributes
frontend calls across the API tier.

## DNS inventory

| Scope | Name | Target |
|---|---|---|
| Public | `erp-web-yo2oo.eastus.cloudapp.azure.com` | Lab 1 firewall public IP |
| Private | `firewall.hub.contoso.internal` | `10.1.0.4` |
| Private | `web.corp.contoso.internal` | `10.2.2.20` |
| Private | `web-zone1/2.corp.contoso.internal` | `10.2.2.11/12` |
| Public | `contoso-portal-yo2oo.eastus.cloudapp.azure.com` | Lab 4 WAF public IP |
| Private | `frontend.online.contoso.internal` | `10.3.1.11`, `10.3.1.12` |
| Private | `fe-zone1/2.online.contoso.internal` | `10.3.1.11/12` |
| Private | `api.online.contoso.internal` | `10.3.2.20` |
| Private | `api-zone1/2.online.contoso.internal` | `10.3.2.11/12` |
| Private endpoint | `sql-contoso-online-yo2oo.database.windows.net` | `10.3.3.4` inside Online VNet |

Private names resolve only from linked VNets. The database's normal Microsoft
hostname resolves through `privatelink.database.windows.net` inside the VNet.

## Interact with the application

Open `http://contoso-portal-yo2oo.eastus.cloudapp.azure.com` and enter a safe
name plus a 3-240 character message. The form calls the API, inserts a row with
a parameterized statement, then reloads the newest 25 rows from Azure SQL.

CLI equivalent:

```bash
PORTAL=http://contoso-portal-yo2oo.eastus.cloudapp.azure.com
curl "$PORTAL/api/health"
curl -X POST -H 'Content-Type: application/json' \
  --data '{"name":"Sid","message":"Portal database test"}' \
  "$PORTAL/api/messages"
curl "$PORTAL/api/messages"
```

## WAF validation

```bash
curl -o /dev/null -w '%{http_code}\n' -H 'X-Lab-Block: true' "$PORTAL/"
curl -o /dev/null -w '%{http_code}\n' "$PORTAL/?id=%27%20OR%201%3D1--"
```

Both return 403 in Prevention mode. Query WAF logs in Log Analytics:

```kusto
AzureDiagnostics
| where Category == "ApplicationGatewayFirewallLog"
| project TimeGenerated, clientIp_s, requestUri_s, ruleId_s, action_s, message_s
| order by TimeGenerated desc
```

## Portal-first learning sequence

1. Create VNet `vnet-contoso-online` (`10.3.0.0/16`) and the App Gateway,
   frontend, API and private-endpoint subnets.
2. Peer Online and Hub VNets in both directions.
3. Create route table default route to `10.1.0.4`; associate frontend/API.
4. Create frontend/API NSGs with only App Gateway-to-HTTP and
   frontend-to-API allowances.
5. Create two frontend and two API Ubuntu VMs, zones 1 and 2, without public IPs.
6. Create the internal Standard Load Balancer at `10.3.2.20`, probe `/health`
   on port 8000 and attach both API NICs.
7. Create private zone `online.contoso.internal`, link the Online VNet and add
   frontend/API pool and node A records.
8. Create Azure SQL Basic, disable public access, create the private endpoint,
   and link `privatelink.database.windows.net`.
9. Create a zone-redundant Standard public IP with an Azure DNS label.
10. Create WAF policy OWASP 3.2 in Prevention mode and custom header rule.
11. Create WAF_v2 Application Gateway in zones 1 and 2 with two frontend IP
    backends and `/health` probe.
12. Send diagnostics to the central Log Analytics workspace, then run the tests.

The Portal does not conveniently author the guest application files; use VM Run
Command or extensions for that portion. Terraform is the reproducible source.

## Terraform rebuild

Update `terraform.tfvars`, then:

```bash
az login --use-device-code
az account set --subscription <new-subscription-id>
./configure-sandbox.sh <subscription-id> <tenant-id> <resource-group> <location>
terraform init -upgrade
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan -out=lab4.tfplan
terraform apply lab4.tfplan
terraform output
```

Always inspect the plan for unexpected destroys or replacements.

## Cost and production gaps

- Application Gateway WAF_v2 and Azure Firewall are the major hourly costs.
- Azure SQL Basic is the cheapest practical lab database and is not zone
  redundant. Production uses a supported vCore zone-redundant tier.
- The lab starts with HTTP. Production requires HTTPS, a certificate in Key
  Vault, HTTP-to-HTTPS redirection, managed identity and secretless DB auth.
- DDoS Network/IP Protection is documented but not deployed for cost reasons.
- The sandbox models landing zones with VNets/tags in one resource group;
  production places Corp and Online in separate governed subscriptions.

## Destroy

```bash
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

Destroy before sandbox expiry when cleanup is not guaranteed.
