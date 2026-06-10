# Lab 5 – Accelerated Networking & VFP Packet Path

## Scenario

> "Where are policies enforced and what changes when Accelerated Networking is enabled?"

This lab provides two side-by-side VMs — one with Accelerated Networking enabled and one without — to explore the **Virtual Filtering Platform (VFP)** and how it enforces NSG/UDR policies regardless of the networking mode.

## Key Takeaway

**VFP is the policy layer.** Accelerated Networking bypasses the host virtual switch for dataplane traffic (using SR-IOV), but VFP policies (NSGs, UDRs) are still enforced via hardware offload on the NIC. AccelNet improves throughput and reduces latency without sacrificing security.

## Architecture

| Resource | Purpose |
|----------|---------|
| VNet (10.240.0.0/16) | Lab network |
| NSG | Demonstrates VFP policy enforcement |
| Standard VM (Standard_D2s_v3) | No AccelNet — traffic via vSwitch |
| AccelNet VM (Standard_D2s_v3) | AccelNet enabled — traffic via SR-IOV VF |

### Packet Path Comparison

| Path | Standard VM | AccelNet VM |
|------|-------------|-------------|
| Dataplane | VM → vSwitch → VFP → Physical NIC | VM → SR-IOV VF → VFP (HW offload) → Physical NIC |
| Policy enforcement | VFP (software) | VFP (hardware offload) |
| NSG enforced? | ✅ Yes | ✅ Yes |

## Deploy to Azure

Click the button below to deploy this lab directly to your Azure subscription:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FPaulJohnston88%2FTechExcellence2026%2Fmain%2Flabs%2Flab5-accelerated-networking-vfp%2Fazuredeploy.json)

### Parameters

| Parameter | Description |
|-----------|-------------|
| `location` | Azure region (defaults to resource group location) |
| `adminUsername` | VM admin username |
| `adminPassword` | VM admin password |

> **Note:** This lab uses `Standard_D2s_v3` VMs (supports Accelerated Networking). Ensure your subscription has quota for DSv3 in the chosen region.

## Manual Deployment

### Bash (Azure CLI)

```bash
# Create resource group
az group create --name te-rg-demo5-accelnet-001 --location francecentral

# Deploy template
az deployment group create \
  --resource-group te-rg-demo5-accelnet-001 \
  --template-file azuredeploy.json \
  --parameters adminUsername=azureuser adminPassword='<YourPassword>'
```

### PowerShell (Azure CLI)

```powershell
# Create resource group
az group create --name te-rg-demo5-accelnet-001 --location francecentral

# Deploy template
az deployment group create `
  --resource-group te-rg-demo5-accelnet-001 `
  --template-file azuredeploy.json `
  --parameters adminUsername=azureuser adminPassword='<YourPassword>'
```

### PowerShell (Az Module)

```powershell
# Create resource group
New-AzResourceGroup -Name te-rg-demo5-accelnet-001 -Location francecentral

# Deploy template
New-AzResourceGroupDeployment `
  -ResourceGroupName te-rg-demo5-accelnet-001 `
  -TemplateFile azuredeploy.json `
  -adminUsername 'azureuser' `
  -adminPassword (ConvertTo-SecureString '<YourPassword>' -AsPlainText -Force)
```

## Demo Steps

1. **Connect to the Standard VM** via Serial Console or Bastion
2. **Check for Mellanox VF** (none on standard):
   ```bash
   lspci | grep -i mellanox
   ```
   → No output — no SR-IOV Virtual Function
3. **Connect to the AccelNet VM**
4. **Check for Mellanox VF** (present with AccelNet):
   ```bash
   lspci | grep -i mellanox
   ```
   → Shows Mellanox ConnectX VF — SR-IOV is active
5. **Check network driver:**
   ```bash
   ethtool -i eth0
   ```
   → Driver is `mlx4_en` or `mlx5_core` (not `hv_netvsc`)
6. **Run iperf3 between VMs** to compare throughput:
   ```bash
   # On one VM (server):
   iperf3 -s

   # On the other VM (client):
   iperf3 -c <other-vm-ip> -t 10
   ```
7. **Verify NSG enforcement** — both VMs respect the same NSG rules:

   **Bash:**
   ```bash
   az network nic show-effective-route-table \
     --resource-group te-rg-demo5-accelnet-001 \
     --name te-nic-demo5-accel-001 -o table
   ```

   **PowerShell:**
   ```powershell
   az network nic show-effective-route-table `
     --resource-group te-rg-demo5-accelnet-001 `
     --name te-nic-demo5-accel-001 -o table

   # Or using Az Module:
   Get-AzEffectiveRouteTable `
     -ResourceGroupName te-rg-demo5-accelnet-001 `
     -NetworkInterfaceName te-nic-demo5-accel-001 | Format-Table
   ```
8. **Discuss:** VFP enforces NSG/UDR on both VMs. AccelNet offloads to hardware, reducing CPU and latency, but security policies are identical.

## Outputs

| Output | Description |
|--------|-------------|
| `standardVmName` | VM without AccelNet |
| `standardVmPrivateIp` | Standard VM private IP |
| `accelNetVmName` | VM with AccelNet |
| `accelNetVmPrivateIp` | AccelNet VM private IP |
| `nsgName` | NSG applied to both |

## Clean Up

**Bash:**
```bash
az group delete --name te-rg-demo5-accelnet-001 --yes --no-wait
```

**PowerShell:**
```powershell
az group delete --name te-rg-demo5-accelnet-001 --yes --no-wait

# Or using Az Module:
Remove-AzResourceGroup -Name te-rg-demo5-accelnet-001 -Force -AsJob
```
