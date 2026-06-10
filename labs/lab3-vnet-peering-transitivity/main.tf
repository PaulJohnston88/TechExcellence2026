#########################################################
# Demo 3 – VNet Peering Transitivity
# Scenario: "Why can't Spoke A reach Spoke B?"
# Shows: Peering is non-transitive. Spoke-to-spoke traffic
#        requires a hub NVA/Firewall + UDRs.
# Key Takeaway: VNet peering does NOT provide transitive
#               routing. You must explicitly route through
#               a hub appliance.
#########################################################

#########################################################
# Resource Group
#########################################################

resource "azurerm_resource_group" "demo3_rg" {
  name     = "te-rg-demo3-peering-001"
  location = "northeurope"
}

#########################################################
# Hub VNet (with NVA subnet)
#########################################################

resource "azurerm_virtual_network" "demo3_hub_vnet" {
  name                = "te-vnet-demo3-hub-001"
  location            = azurerm_resource_group.demo3_rg.location
  resource_group_name = azurerm_resource_group.demo3_rg.name
  address_space       = ["10.220.0.0/16"]
}

resource "azurerm_subnet" "demo3_hub_nva_subnet" {
  name                 = "te-snet-demo3-nva-001"
  resource_group_name  = azurerm_resource_group.demo3_rg.name
  virtual_network_name = azurerm_virtual_network.demo3_hub_vnet.name
  address_prefixes     = ["10.220.1.0/24"]
}

#########################################################
# Spoke A VNet
#########################################################

resource "azurerm_virtual_network" "demo3_spoke_a_vnet" {
  name                = "te-vnet-demo3-spokea-001"
  location            = azurerm_resource_group.demo3_rg.location
  resource_group_name = azurerm_resource_group.demo3_rg.name
  address_space       = ["10.221.0.0/16"]
}

resource "azurerm_subnet" "demo3_spoke_a_subnet" {
  name                 = "te-snet-demo3-spokea-001"
  resource_group_name  = azurerm_resource_group.demo3_rg.name
  virtual_network_name = azurerm_virtual_network.demo3_spoke_a_vnet.name
  address_prefixes     = ["10.221.1.0/24"]
}

#########################################################
# Spoke B VNet
#########################################################

resource "azurerm_virtual_network" "demo3_spoke_b_vnet" {
  name                = "te-vnet-demo3-spokeb-001"
  location            = azurerm_resource_group.demo3_rg.location
  resource_group_name = azurerm_resource_group.demo3_rg.name
  address_space       = ["10.222.0.0/16"]
}

resource "azurerm_subnet" "demo3_spoke_b_subnet" {
  name                 = "te-snet-demo3-spokeb-001"
  resource_group_name  = azurerm_resource_group.demo3_rg.name
  virtual_network_name = azurerm_virtual_network.demo3_spoke_b_vnet.name
  address_prefixes     = ["10.222.1.0/24"]
}

#########################################################
# VNet Peering: Hub <-> Spoke A
#########################################################

resource "azurerm_virtual_network_peering" "demo3_hub_to_spoke_a" {
  name                         = "hub-to-spokea"
  resource_group_name          = azurerm_resource_group.demo3_rg.name
  virtual_network_name         = azurerm_virtual_network.demo3_hub_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.demo3_spoke_a_vnet.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "demo3_spoke_a_to_hub" {
  name                         = "spokea-to-hub"
  resource_group_name          = azurerm_resource_group.demo3_rg.name
  virtual_network_name         = azurerm_virtual_network.demo3_spoke_a_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.demo3_hub_vnet.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

#########################################################
# VNet Peering: Hub <-> Spoke B
#########################################################

resource "azurerm_virtual_network_peering" "demo3_hub_to_spoke_b" {
  name                         = "hub-to-spokeb"
  resource_group_name          = azurerm_resource_group.demo3_rg.name
  virtual_network_name         = azurerm_virtual_network.demo3_hub_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.demo3_spoke_b_vnet.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "demo3_spoke_b_to_hub" {
  name                         = "spokeb-to-hub"
  resource_group_name          = azurerm_resource_group.demo3_rg.name
  virtual_network_name         = azurerm_virtual_network.demo3_spoke_b_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.demo3_hub_vnet.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

#########################################################
# Hub NVA (Linux VM with IP Forwarding enabled)
# This acts as the router between spokes
#########################################################

resource "azurerm_network_interface" "demo3_nva_nic" {
  name                           = "te-nic-demo3-nva-001"
  location                       = azurerm_resource_group.demo3_rg.location
  resource_group_name            = azurerm_resource_group.demo3_rg.name
  ip_forwarding_enabled          = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo3_hub_nva_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.220.1.4"
  }
}

resource "azurerm_linux_virtual_machine" "demo3_nva_vm" {
  name                            = "te-vm-demo3-nva-001"
  location                        = azurerm_resource_group.demo3_rg.location
  resource_group_name             = azurerm_resource_group.demo3_rg.name
  size                            = "Standard_B2s"
  admin_username                  = "azureuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.demo3_nva_nic.id]

  # Enable IP forwarding in the OS via cloud-init
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    EOF
  )

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
# Spoke A VM
#########################################################

resource "azurerm_network_interface" "demo3_spoke_a_nic" {
  name                = "te-nic-demo3-spokea-001"
  location            = azurerm_resource_group.demo3_rg.location
  resource_group_name = azurerm_resource_group.demo3_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo3_spoke_a_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "demo3_spoke_a_vm" {
  name                            = "te-vm-demo3-spokea-001"
  location                        = azurerm_resource_group.demo3_rg.location
  resource_group_name             = azurerm_resource_group.demo3_rg.name
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.demo3_spoke_a_nic.id]

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
# Spoke B VM
#########################################################

resource "azurerm_network_interface" "demo3_spoke_b_nic" {
  name                = "te-nic-demo3-spokeb-001"
  location            = azurerm_resource_group.demo3_rg.location
  resource_group_name = azurerm_resource_group.demo3_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo3_spoke_b_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "demo3_spoke_b_vm" {
  name                            = "te-vm-demo3-spokeb-001"
  location                        = azurerm_resource_group.demo3_rg.location
  resource_group_name             = azurerm_resource_group.demo3_rg.name
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.demo3_spoke_b_nic.id]

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
# Route Tables for Spokes (initially WITHOUT routes)
# Demo flow:
#   1. Show Spoke A can ping Hub NVA (works)
#   2. Show Spoke A CANNOT ping Spoke B (fails - non-transitive)
#   3. Add UDRs pointing spoke-to-spoke via NVA (fix)
#   4. Show Spoke A CAN now ping Spoke B (works)
#########################################################

resource "azurerm_route_table" "demo3_spoke_a_rt" {
  name                          = "te-rt-demo3-spokea-001"
  location                      = azurerm_resource_group.demo3_rg.location
  resource_group_name           = azurerm_resource_group.demo3_rg.name
  bgp_route_propagation_enabled = false

  # Route to Spoke B via Hub NVA
  route {
    name                   = "to-spoke-b"
    address_prefix         = "10.222.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.220.1.4" # NVA IP
  }
}

resource "azurerm_route_table" "demo3_spoke_b_rt" {
  name                          = "te-rt-demo3-spokeb-001"
  location                      = azurerm_resource_group.demo3_rg.location
  resource_group_name           = azurerm_resource_group.demo3_rg.name
  bgp_route_propagation_enabled = false

  # Route to Spoke A via Hub NVA
  route {
    name                   = "to-spoke-a"
    address_prefix         = "10.221.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.220.1.4" # NVA IP
  }
}

# NOTE: These associations are the "fix" step in the demo.
# To show the broken state first, comment these out, deploy,
# demonstrate the failure, then uncomment and apply.

resource "azurerm_subnet_route_table_association" "demo3_spoke_a_rt_assoc" {
  subnet_id      = azurerm_subnet.demo3_spoke_a_subnet.id
  route_table_id = azurerm_route_table.demo3_spoke_a_rt.id
}

resource "azurerm_subnet_route_table_association" "demo3_spoke_b_rt_assoc" {
  subnet_id      = azurerm_subnet.demo3_spoke_b_subnet.id
  route_table_id = azurerm_route_table.demo3_spoke_b_rt.id
}

#########################################################
# NSG allowing ICMP for ping tests
#########################################################

resource "azurerm_network_security_group" "demo3_nsg" {
  name                = "te-nsg-demo3-001"
  location            = azurerm_resource_group.demo3_rg.location
  resource_group_name = azurerm_resource_group.demo3_rg.name

  security_rule {
    name                       = "AllowICMP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.220.0.0/14" # Covers all demo3 ranges
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "demo3_hub_nsg" {
  subnet_id                 = azurerm_subnet.demo3_hub_nva_subnet.id
  network_security_group_id = azurerm_network_security_group.demo3_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "demo3_spoke_a_nsg" {
  subnet_id                 = azurerm_subnet.demo3_spoke_a_subnet.id
  network_security_group_id = azurerm_network_security_group.demo3_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "demo3_spoke_b_nsg" {
  subnet_id                 = azurerm_subnet.demo3_spoke_b_subnet.id
  network_security_group_id = azurerm_network_security_group.demo3_nsg.id
}

#########################################################
# Outputs
# Demo commands:
#   1. From Spoke A VM: ping 10.222.1.4 (Spoke B) → FAILS
#   2. From Spoke A VM: ping 10.220.1.4 (Hub NVA) → WORKS
#   3. Apply UDRs, then ping 10.222.1.4 again → WORKS
#   4. az network nic show-effective-route-table (show UDR)
#########################################################

output "demo3_hub_nva_ip" {
  description = "Hub NVA private IP (IP forwarding enabled)"
  value       = azurerm_network_interface.demo3_nva_nic.private_ip_address
}

output "demo3_spoke_a_vm_ip" {
  description = "Spoke A VM private IP"
  value       = azurerm_network_interface.demo3_spoke_a_nic.private_ip_address
}

output "demo3_spoke_b_vm_ip" {
  description = "Spoke B VM private IP"
  value       = azurerm_network_interface.demo3_spoke_b_nic.private_ip_address
}

output "demo3_spoke_a_vm_name" {
  description = "Spoke A VM name"
  value       = azurerm_linux_virtual_machine.demo3_spoke_a_vm.name
}

output "demo3_spoke_b_vm_name" {
  description = "Spoke B VM name"
  value       = azurerm_linux_virtual_machine.demo3_spoke_b_vm.name
}

output "demo3_nva_vm_name" {
  description = "NVA VM name (hub router)"
  value       = azurerm_linux_virtual_machine.demo3_nva_vm.name
}
