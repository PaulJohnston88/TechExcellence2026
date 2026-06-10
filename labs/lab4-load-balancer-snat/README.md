# Lab 4 – Load Balancer SNAT Exhaustion

## Scenario

> "It works… then suddenly fails under load."

This lab demonstrates **SNAT port exhaustion** when using a Standard Load Balancer for outbound connectivity. You'll compare the limited SNAT port allocation of an outbound rule with the scalable approach of a **NAT Gateway**.

## Key Takeaway

Standard Load Balancer outbound rules allocate a fixed number of SNAT ports per backend VM. Under high outbound connection load, ports exhaust and connections fail. **NAT Gateway** provides ~64K ports per public IP and auto-scales — it's the recommended solution for heavy outbound workloads.

## Architecture

| Resource | Purpose |
|----------|---------|
| VNet (10.230.0.0/16) | Lab network |
| Standard Load Balancer | Outbound rule with 1024 ports/VM |
| NAT Gateway | ~64K SNAT ports per public IP |
| LB Backend VM | Demonstrates SNAT exhaustion |
| NAT Gateway VM | Demonstrates scalable outbound |

## Deploy to Azure

Click the button below to deploy this lab directly to your Azure subscription:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FPaulJohnston88%2FTechExcellence2026%2Fmain%2Flabs%2Flab4-load-balancer-snat%2Fazuredeploy.json)

### Parameters

| Parameter | Description |
|-----------|-------------|
| `location` | Azure region (defaults to resource group location) |
| `adminUsername` | VM admin username |
| `adminPassword` | VM admin password |

## Manual Deployment

### Bash (Azure CLI)

```bash
# Create resource group
az group create --name te-rg-demo4-snat-001 --location westeurope

# Deploy template
az deployment group create \
  --resource-group te-rg-demo4-snat-001 \
  --template-file azuredeploy.json \
  --parameters adminUsername=azureuser adminPassword='<YourPassword>'
```

### PowerShell (Azure CLI)

```powershell
# Create resource group
az group create --name te-rg-demo4-snat-001 --location westeurope

# Deploy template
az deployment group create `
  --resource-group te-rg-demo4-snat-001 `
  --template-file azuredeploy.json `
  --parameters adminUsername=azureuser adminPassword='<YourPassword>'
```

### PowerShell (Az Module)

```powershell
# Create resource group
New-AzResourceGroup -Name te-rg-demo4-snat-001 -Location westeurope

# Deploy template
New-AzResourceGroupDeployment `
  -ResourceGroupName te-rg-demo4-snat-001 `
  -TemplateFile azuredeploy.json `
  -adminUsername 'azureuser' `
  -adminPassword (ConvertTo-SecureString '<YourPassword>' -AsPlainText -Force)
```

## Demo Steps

1. **Connect to the LB Backend VM** via Serial Console or Bastion
2. **Generate high outbound connection load:**
   ```bash
   for i in $(seq 1 2000); do curl -s -o /dev/null http://example.com & done
   wait
   ```
3. **Observe failures** — some connections will fail due to SNAT exhaustion
4. **Check Azure Metrics:**
   - Navigate to Load Balancer → Metrics → "SNAT Connection Count"
   - Filter by state: "Failed" — shows exhaustion
5. **Connect to the NAT Gateway VM** via Serial Console
6. **Run the same test:**
   ```bash
   for i in $(seq 1 2000); do curl -s -o /dev/null http://example.com & done
   wait
   ```
   → No failures — NAT Gateway has ~64K ports available
7. **Discuss:**
   - LB outbound rule: only 1024 ports allocated per VM
   - NAT Gateway: ~64,512 ports per public IP, auto-distributes
   - Real-world fix: Add NAT Gateway to LB backend subnets (NAT GW takes precedence)

## Outputs

| Output | Description |
|--------|-------------|
| `lbPublicIp` | Load Balancer public IP |
| `natGatewayPublicIp` | NAT Gateway public IP |
| `allocatedOutboundPorts` | SNAT ports per VM (1024) |
| `lbVmPrivateIp` | LB backend VM private IP |
| `natVmPrivateIp` | NAT Gateway VM private IP |

## Clean Up

**Bash:**
```bash
az group delete --name te-rg-demo4-snat-001 --yes --no-wait
```

**PowerShell:**
```powershell
az group delete --name te-rg-demo4-snat-001 --yes --no-wait

# Or using Az Module:
Remove-AzResourceGroup -Name te-rg-demo4-snat-001 -Force -AsJob
```
