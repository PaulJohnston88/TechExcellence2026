# Lab 1 – Routing / UDR / NAT Gateway

## Scenario

> "Why is outbound traffic using the wrong IP?"

This lab demonstrates how Azure routing decisions determine which public IP is used for outbound traffic. You'll explore the interaction between **NAT Gateway**, **Azure Firewall**, and **User-Defined Routes (UDRs)**.

## Key Takeaway

The egress decision point is: **NAT Gateway vs Firewall vs default Internet routing**. UDRs override the default path, and NAT Gateway takes precedence when no UDR is present.

## Architecture

| Resource | Purpose |
|----------|---------|
| VNet (10.200.0.0/16) | Lab network |
| NAT Gateway + Public IP | Provides predictable egress IP |
| Azure Firewall + Public IP | Alternative egress path |
| UDR (0.0.0.0/0 → Firewall) | Forces traffic via firewall |
| Linux VM | Test workload |

## Deploy to Azure

Click the button below to deploy this lab directly to your Azure subscription:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FPaulJohnston88%2FTechExcellence2026%2Fmain%2Flabs%2Flab1-routing-udr-nat-gateway%2Fazuredeploy.json)

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
az group create --name te-rg-demo1-routing-001 --location uksouth

# Deploy template
az deployment group create \
  --resource-group te-rg-demo1-routing-001 \
  --template-file azuredeploy.json \
  --parameters adminUsername=azureuser adminPassword='<YourPassword>'
```

### PowerShell (Azure CLI)

```powershell
# Create resource group
az group create --name te-rg-demo1-routing-001 --location uksouth

# Deploy template
az deployment group create `
  --resource-group te-rg-demo1-routing-001 `
  --template-file azuredeploy.json `
  --parameters adminUsername=azureuser adminPassword='<YourPassword>'
```

### PowerShell (Az Module)

```powershell
# Create resource group
New-AzResourceGroup -Name te-rg-demo1-routing-001 -Location uksouth

# Deploy template
New-AzResourceGroupDeployment `
  -ResourceGroupName te-rg-demo1-routing-001 `
  -TemplateFile azuredeploy.json `
  -adminUsername 'azureuser' `
  -adminPassword (ConvertTo-SecureString '<YourPassword>' -AsPlainText -Force)
```

## Demo Steps

1. **Connect to the VM** via Serial Console or Bastion
2. **Check current egress IP:**
   ```bash
   curl ifconfig.me
   ```
   → Traffic goes via the **Firewall** (UDR is active by default)
3. **Remove the UDR association** from the subnet (via Portal or CLI):

   **Bash:**
   ```bash
   az network vnet subnet update \
     --resource-group te-rg-demo1-routing-001 \
     --vnet-name te-vnet-demo1-001 \
     --name te-snet-demo1-workload-001 \
     --remove routeTable
   ```

   **PowerShell:**
   ```powershell
   az network vnet subnet update `
     --resource-group te-rg-demo1-routing-001 `
     --vnet-name te-vnet-demo1-001 `
     --name te-snet-demo1-workload-001 `
     --remove routeTable
   ```
4. **Check egress IP again:**
   ```bash
   curl ifconfig.me
   ```
   → Traffic now exits via the **NAT Gateway** IP
5. **Discuss:** Why did the path change? (UDR > NAT Gateway > default)

## Outputs

| Output | Description |
|--------|-------------|
| `natGatewayPublicIp` | NAT Gateway egress IP |
| `firewallPublicIp` | Firewall egress IP |
| `vmPrivateIp` | VM private IP |

## Clean Up

**Bash:**
```bash
az group delete --name te-rg-demo1-routing-001 --yes --no-wait
```

**PowerShell:**
```powershell
az group delete --name te-rg-demo1-routing-001 --yes --no-wait

# Or using Az Module:
Remove-AzResourceGroup -Name te-rg-demo1-routing-001 -Force -AsJob
```
