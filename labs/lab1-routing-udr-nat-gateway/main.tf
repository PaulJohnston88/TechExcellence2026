#########################################################
# Demo 1 – Routing / UDR / NAT Gateway
# Scenario: "Why is outbound traffic using the wrong IP?"
# Shows: VM in a subnet, attach NAT Gateway, show changed
#        public IP, then discuss UDR forcing traffic to firewall.
# Key Takeaway: Clarifies the egress decision point — NAT
#               Gateway vs firewall vs default Internet routing.
#########################################################

#########################################################
# Resource Group
#########################################################

resource "azurerm_resource_group" "demo1_rg" {
  name     = "te-rg-demo1-routing-001"
  location = "uk south"
}

#########################################################
# Virtual Network & Subnets
#########################################################

resource "azurerm_virtual_network" "demo1_vnet" {
  name                = "te-vnet-demo1-001"
  location            = azurerm_resource_group.demo1_rg.location
  resource_group_name = azurerm_resource_group.demo1_rg.name
  address_space       = ["10.200.0.0/16"]
}

resource "azurerm_subnet" "demo1_workload_subnet" {
  name                 = "te-snet-demo1-workload-001"
  resource_group_name  = azurerm_resource_group.demo1_rg.name
  virtual_network_name = azurerm_virtual_network.demo1_vnet.name
  address_prefixes     = ["10.200.1.0/24"]
}

resource "azurerm_subnet" "demo1_firewall_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.demo1_rg.name
  virtual_network_name = azurerm_virtual_network.demo1_vnet.name
  address_prefixes     = ["10.200.0.0/26"]
}

#########################################################
# NAT Gateway (demonstrates egress with predictable IP)
#########################################################

resource "azurerm_public_ip" "demo1_nat_pip" {
  name                = "te-pip-nat-demo1-001"
  location            = azurerm_resource_group.demo1_rg.location
  resource_group_name = azurerm_resource_group.demo1_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "demo1_nat_gw" {
  name                    = "te-natgw-demo1-001"
  location                = azurerm_resource_group.demo1_rg.location
  resource_group_name     = azurerm_resource_group.demo1_rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_association" "demo1_nat_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.demo1_nat_gw.id
  public_ip_address_id = azurerm_public_ip.demo1_nat_pip.id
}

resource "azurerm_subnet_nat_gateway_association" "demo1_nat_subnet_assoc" {
  subnet_id      = azurerm_subnet.demo1_workload_subnet.id
  nat_gateway_id = azurerm_nat_gateway.demo1_nat_gw.id
}

#########################################################
# Azure Firewall (alternative egress path via UDR)
#########################################################

resource "azurerm_public_ip" "demo1_fw_pip" {
  name                = "te-pip-fw-demo1-001"
  location            = azurerm_resource_group.demo1_rg.location
  resource_group_name = azurerm_resource_group.demo1_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "demo1_fw_policy" {
  name                = "te-fwpol-demo1-001"
  location            = azurerm_resource_group.demo1_rg.location
  resource_group_name = azurerm_resource_group.demo1_rg.name
  sku                 = "Standard"
}

resource "azurerm_firewall" "demo1_fw" {
  name                = "te-fw-demo1-001"
  location            = azurerm_resource_group.demo1_rg.location
  resource_group_name = azurerm_resource_group.demo1_rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.demo1_fw_policy.id

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.demo1_firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.demo1_fw_pip.id
  }
}

#########################################################
# Route Table - UDR forcing traffic via Firewall
# NOTE: When this route table is associated, traffic goes
#       via the firewall instead of the NAT Gateway.
#       Dissociate to show NAT Gateway taking over egress.
#########################################################

resource "azurerm_route_table" "demo1_udr" {
  name                          = "te-rt-demo1-via-fw-001"
  location                      = azurerm_resource_group.demo1_rg.location
  resource_group_name           = azurerm_resource_group.demo1_rg.name
  bgp_route_propagation_enabled = false

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.demo1_fw.ip_configuration[0].private_ip_address
  }
}

# Toggle this association on/off to demonstrate egress path changes
resource "azurerm_subnet_route_table_association" "demo1_udr_assoc" {
  subnet_id      = azurerm_subnet.demo1_workload_subnet.id
  route_table_id = azurerm_route_table.demo1_udr.id
}

#########################################################
# Test VM (use curl ifconfig.me to show egress IP)
#########################################################

resource "azurerm_network_interface" "demo1_vm_nic" {
  name                = "te-nic-demo1-vm-001"
  location            = azurerm_resource_group.demo1_rg.location
  resource_group_name = azurerm_resource_group.demo1_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo1_workload_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "demo1_vm" {
  name                            = "te-vm-demo1-001"
  location                        = azurerm_resource_group.demo1_rg.location
  resource_group_name             = azurerm_resource_group.demo1_rg.name
  size                            = "Standard_B2s"
  admin_username                  = "azureuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.demo1_vm_nic.id]

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
# Outputs - Show the egress IPs for comparison
#########################################################

output "demo1_nat_gateway_public_ip" {
  description = "NAT Gateway public IP (egress when no UDR override)"
  value       = azurerm_public_ip.demo1_nat_pip.ip_address
}

output "demo1_firewall_public_ip" {
  description = "Firewall public IP (egress when UDR is active)"
  value       = azurerm_public_ip.demo1_fw_pip.ip_address
}

output "demo1_vm_private_ip" {
  description = "VM private IP"
  value       = azurerm_network_interface.demo1_vm_nic.private_ip_address
}
