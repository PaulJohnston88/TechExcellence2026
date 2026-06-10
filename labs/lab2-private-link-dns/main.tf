#########################################################
# Demo 2 – Private Link vs Public Endpoint
# Scenario: "Why is traffic still going over public even
#            though a private endpoint exists?"
# Shows: Storage Account with private endpoint, DNS
#        mismatch using nslookup, public vs private resolution.
# Key Takeaway: Private Link adoption is fundamentally
#               DNS-driven.
#########################################################

#########################################################
# Resource Group
#########################################################

resource "azurerm_resource_group" "demo2_rg" {
  name     = "te-rg-demo2-privatelink-001"
  location = "uk south"
}

#########################################################
# Virtual Network & Subnets
#########################################################

resource "azurerm_virtual_network" "demo2_vnet" {
  name                = "te-vnet-demo2-001"
  location            = azurerm_resource_group.demo2_rg.location
  resource_group_name = azurerm_resource_group.demo2_rg.name
  address_space       = ["10.210.0.0/16"]
}

resource "azurerm_subnet" "demo2_workload_subnet" {
  name                 = "te-snet-demo2-workload-001"
  resource_group_name  = azurerm_resource_group.demo2_rg.name
  virtual_network_name = azurerm_virtual_network.demo2_vnet.name
  address_prefixes     = ["10.210.1.0/24"]
}

resource "azurerm_subnet" "demo2_pe_subnet" {
  name                 = "te-snet-demo2-pe-001"
  resource_group_name  = azurerm_resource_group.demo2_rg.name
  virtual_network_name = azurerm_virtual_network.demo2_vnet.name
  address_prefixes     = ["10.210.2.0/24"]
}

#########################################################
# Storage Account (the PaaS service with private endpoint)
#########################################################

resource "random_string" "demo2_storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_storage_account" "demo2_storage" {
  name                          = "tedemo2sa${random_string.demo2_storage_suffix.result}"
  location                      = azurerm_resource_group.demo2_rg.location
  resource_group_name           = azurerm_resource_group.demo2_rg.name
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = true # Intentionally left open to show dual-path
}

#########################################################
# Private DNS Zone for Blob Storage
# Without this linked to the VNet, nslookup resolves to
# the public IP — demonstrating the DNS mismatch problem.
#########################################################

resource "azurerm_private_dns_zone" "demo2_blob_dns" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.demo2_rg.name
}

# Link DNS zone to VNet — toggle this to show the DNS behavior
resource "azurerm_private_dns_zone_virtual_network_link" "demo2_dns_link" {
  name                  = "demo2-blob-dns-link"
  resource_group_name   = azurerm_resource_group.demo2_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.demo2_blob_dns.name
  virtual_network_id    = azurerm_virtual_network.demo2_vnet.id
  registration_enabled  = false
}

#########################################################
# Private Endpoint for Blob Storage
#########################################################

resource "azurerm_private_endpoint" "demo2_blob_pe" {
  name                = "te-pe-demo2-blob-001"
  location            = azurerm_resource_group.demo2_rg.location
  resource_group_name = azurerm_resource_group.demo2_rg.name
  subnet_id           = azurerm_subnet.demo2_pe_subnet.id

  private_service_connection {
    name                           = "te-psc-demo2-blob-001"
    private_connection_resource_id = azurerm_storage_account.demo2_storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.demo2_blob_dns.id]
  }
}

#########################################################
# Test VM (use nslookup to show DNS resolution behavior)
#########################################################

resource "azurerm_network_interface" "demo2_vm_nic" {
  name                = "te-nic-demo2-vm-001"
  location            = azurerm_resource_group.demo2_rg.location
  resource_group_name = azurerm_resource_group.demo2_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo2_workload_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "demo2_vm" {
  name                            = "te-vm-demo2-001"
  location                        = azurerm_resource_group.demo2_rg.location
  resource_group_name             = azurerm_resource_group.demo2_rg.name
  size                            = "Standard_B2s"
  admin_username                  = "azureuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.demo2_vm_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

#########################################################
# Outputs
#########################################################

output "demo2_storage_account_name" {
  description = "Storage account name for nslookup testing"
  value       = azurerm_storage_account.demo2_storage.name
}

output "demo2_storage_blob_fqdn" {
  description = "Run: nslookup <this>.blob.core.windows.net from the VM"
  value       = "${azurerm_storage_account.demo2_storage.name}.blob.core.windows.net"
}

output "demo2_private_endpoint_ip" {
  description = "Expected private IP from DNS resolution when link is active"
  value       = azurerm_private_endpoint.demo2_blob_pe.private_service_connection[0].private_ip_address
}

output "demo2_vm_private_ip" {
  description = "VM private IP for SSH access"
  value       = azurerm_network_interface.demo2_vm_nic.private_ip_address
}
