# Azure Networking Labs – Tech Excellence 2026

Interactive hands-on labs for the **EngOps Networking Training** session. Each lab demonstrates a common Azure networking misconception with a real, deployable environment.

## Labs

| # | Lab | Scenario | Deploy |
|---|-----|----------|--------|
| 1 | [Routing / UDR / NAT Gateway](labs/lab1-routing-udr-nat-gateway/) | "Why is outbound traffic using the wrong IP?" | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FPaulJohnston88%2FTechExcellence2026%2Fmain%2Flabs%2Flab1-routing-udr-nat-gateway%2Fazuredeploy.json) |
| 2 | [Private Link & DNS](labs/lab2-private-link-dns/) | "Why is traffic still going over public?" | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FPaulJohnston88%2FTechExcellence2026%2Fmain%2Flabs%2Flab2-private-link-dns%2Fazuredeploy.json) |
| 3 | [Load Balancer SNAT Exhaustion](labs/lab4-load-balancer-snat/) | "It works… then suddenly fails under load" | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FPaulJohnston88%2FTechExcellence2026%2Fmain%2Flabs%2Flab4-load-balancer-snat%2Fazuredeploy.json) |
| 4 | [VNet Peering Transitivity](labs/lab3-vnet-peering-transitivity/) | "Why can't Spoke A reach Spoke B?" | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FPaulJohnston88%2FTechExcellence2026%2Fmain%2Flabs%2Flab3-vnet-peering-transitivity%2Fazuredeploy.json) |
| 5 | [Accelerated Networking & VFP](labs/lab5-accelerated-networking-vfp/) | "Where are policies enforced with AccelNet?" | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FPaulJohnston88%2FTechExcellence2026%2Fmain%2Flabs%2Flab5-accelerated-networking-vfp%2Fazuredeploy.json) |

## Quick Start

### Option A: One-Click Deploy (No Terraform Required)

1. Click the **"Deploy to Azure"** button for the lab you want
2. Sign in to the Azure Portal
3. Fill in the parameters (admin username/password)
4. Click **Review + Create** → **Create**
5. Once deployed, follow the demo steps in the lab's README

### Option B: Terraform

```bash
git clone https://github.com/PaulJohnston88/TechExcellence2026.git
cd TechExcellence2026
terraform init
terraform apply
```

> **Note:** The Terraform files deploy all 5 labs simultaneously. Ensure you have sufficient vCPU quota (≈14 cores across regions).

## Prerequisites

- Azure subscription with **Contributor** access
- Sufficient vCPU quota (labs use different regions to avoid quota limits):

| Lab | Region (Terraform default) | VM Size | Cores Needed |
|-----|---------------------------|---------|--------------|
| 1 | UK South | Standard_B2s | 2 |
| 2 | UK South | Standard_B2s | 2 |
| 3 | West Europe | Standard_B2s | 4 (2 VMs) |
| 4 | North Europe | Standard_B2s | 4 (3 VMs) |
| 5 | France Central | Standard_D2s_v3 | 4 (2 VMs) |

> **Tip:** When using the "Deploy to Azure" button, you can choose any region with available quota when creating the resource group.

- For Terraform: Terraform ≥ 1.5 with AzureRM provider ~> 4.0

## Repository Structure

```
├── README.md                              # This file
├── labs/
│   ├── lab1-routing-udr-nat-gateway/
│   │   ├── azuredeploy.json               # ARM template
│   │   └── README.md                      # Lab guide
│   ├── lab2-private-link-dns/
│   │   ├── azuredeploy.json
│   │   └── README.md
│   ├── lab4-load-balancer-snat/
│   │   ├── azuredeploy.json
│   │   └── README.md
│   ├── lab3-vnet-peering-transitivity/
│   │   ├── azuredeploy.json
│   │   └── README.md
│   └── lab5-accelerated-networking-vfp/
│       ├── azuredeploy.json
│       └── README.md
├── terraform.tf                           # Provider configuration
├── demo1-routing-udr-nat-gateway.tf       # Terraform - Lab 1
├── demo2-private-link-dns.tf              # Terraform - Lab 2
├── demo4-load-balancer-snat.tf            # Terraform - Lab 3
├── demo3-vnet-peering-transitivity.tf     # Terraform - Lab 4
└── demo5-accelerated-networking-vfp.tf    # Terraform - Lab 5
```

## Estimated Costs

| Lab | Key Resources | ~Cost/hour |
|-----|---------------|------------|
| 1 | Azure Firewall + NAT GW + VM | ~£1.20 |
| 2 | Storage + Private Endpoint + VM | ~£0.05 |
| 3 | Load Balancer + NAT GW + 2 VMs | ~£0.10 |
| 4 | 3 VMs (hub-spoke) | ~£0.08 |
| 5 | 2 VMs (D2s_v3) | ~£0.15 |

> **Important:** Remember to delete resource groups after each lab to avoid ongoing charges. Lab 1 (Azure Firewall) is the most expensive.

## Clean Up All Labs

```bash
az group delete --name te-rg-demo1-routing-001 --yes --no-wait
az group delete --name te-rg-demo2-privatelink-001 --yes --no-wait
az group delete --name te-rg-demo3-peering-001 --yes --no-wait
az group delete --name te-rg-demo4-snat-001 --yes --no-wait
az group delete --name te-rg-demo5-accelnet-001 --yes --no-wait
```

## Contributing

This repository supports the EngOps Networking Training 2026 session. For questions or suggestions, please open an issue.

## License

MIT
