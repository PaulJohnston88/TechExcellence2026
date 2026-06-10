#########################################################
# Demo 5 – Accelerated Networking + VFP Packet Path
# Scenario: "Where are policies enforced and what changes
#            when Accelerated Networking is enabled?"
# Shows: Two VMs side-by-side — one with AccelNet enabled,
#        one without. Compare NIC effective routes, NSG
#        enforcement, and performance.
# Key Takeaway: VFP is the policy layer; AccelNet bypasses
#               the host vSwitch for dataplane but VFP
#               policies are still enforced on the NIC.
#########################################################

#########################################################
# Resource Group
#########################################################

resource "azurerm_resource_group" "demo5_rg" {
  name     = "te-rg-demo5-accelnet-001"
  location = "francecentral"
}

#########################################################
# Virtual Network & Subnet
#########################################################

resource "azurerm_virtual_network" "demo5_vnet" {
  name                = "te-vnet-demo5-001"
  location            = azurerm_resource_group.demo5_rg.location
  resource_group_name = azurerm_resource_group.demo5_rg.name
  address_space       = ["10.240.0.0/16"]
}

resource "azurerm_subnet" "demo5_workload_subnet" {
  name                 = "te-snet-demo5-workload-001"
  resource_group_name  = azurerm_resource_group.demo5_rg.name
  virtual_network_name = azurerm_virtual_network.demo5_vnet.name
  address_prefixes     = ["10.240.1.0/24"]
}

#########################################################
# Network Security Group (demonstrates VFP policy enforcement)
# NSG rules are enforced by VFP regardless of AccelNet
#########################################################

resource "azurerm_network_security_group" "demo5_nsg" {
  name                = "te-nsg-demo5-001"
  location            = azurerm_resource_group.demo5_rg.location
  resource_group_name = azurerm_resource_group.demo5_rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowICMP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.240.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "demo5_nsg_assoc" {
  subnet_id                 = azurerm_subnet.demo5_workload_subnet.id
  network_security_group_id = azurerm_network_security_group.demo5_nsg.id
}

#########################################################
# VM 1 - WITHOUT Accelerated Networking
# Packet path: VM → vSwitch → VFP → Physical NIC
#########################################################

resource "azurerm_network_interface" "demo5_standard_nic" {
  name                           = "te-nic-demo5-standard-001"
  location                       = azurerm_resource_group.demo5_rg.location
  resource_group_name            = azurerm_resource_group.demo5_rg.name
  accelerated_networking_enabled = false

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo5_workload_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "demo5_standard_vm" {
  name                            = "te-vm-demo5-std-001"
  location                        = azurerm_resource_group.demo5_rg.location
  resource_group_name             = azurerm_resource_group.demo5_rg.name
  size                            = "Standard_D2s_v3" # Supports AccelNet
  admin_username                  = "azureuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.demo5_standard_nic.id]

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
# VM 2 - WITH Accelerated Networking
# Packet path: VM → SR-IOV VF → VFP (hardware offload) → Physical NIC
# Host vSwitch is bypassed for data; VFP still enforces policy
#########################################################

resource "azurerm_network_interface" "demo5_accelnet_nic" {
  name                           = "te-nic-demo5-accel-001"
  location                       = azurerm_resource_group.demo5_rg.location
  resource_group_name            = azurerm_resource_group.demo5_rg.name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo5_workload_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "demo5_accelnet_vm" {
  name                            = "te-vm-demo5-accel-001"
  location                        = azurerm_resource_group.demo5_rg.location
  resource_group_name             = azurerm_resource_group.demo5_rg.name
  size                            = "Standard_D2s_v3" # Supports AccelNet
  admin_username                  = "azureuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.demo5_accelnet_nic.id]

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
# Demo flow:
#   1. SSH into both VMs
#   2. On standard VM: lspci | grep -i mellanox (no VF)
#      On accelnet VM: lspci | grep -i mellanox (VF present)
#   3. On accelnet VM: ethtool -i eth0 (driver = mlx4/5_en)
#   4. Run iperf3 between VMs to show throughput difference
#   5. Show NSG flow logs — both VMs have policies enforced
#   6. Discuss: VFP enforces NSG/UDR on both, but AccelNet
#      offloads to hardware, reducing CPU and latency
#########################################################

output "demo5_standard_vm_name" {
  description = "VM without Accelerated Networking"
  value       = azurerm_linux_virtual_machine.demo5_standard_vm.name
}

output "demo5_standard_vm_private_ip" {
  description = "Standard VM private IP"
  value       = azurerm_network_interface.demo5_standard_nic.private_ip_address
}

output "demo5_accelnet_vm_name" {
  description = "VM with Accelerated Networking"
  value       = azurerm_linux_virtual_machine.demo5_accelnet_vm.name
}

output "demo5_accelnet_vm_private_ip" {
  description = "AccelNet VM private IP"
  value       = azurerm_network_interface.demo5_accelnet_nic.private_ip_address
}

output "demo5_accelnet_enabled" {
  description = "Confirms AccelNet is enabled on the NIC"
  value       = azurerm_network_interface.demo5_accelnet_nic.accelerated_networking_enabled
}

output "demo5_nsg_name" {
  description = "NSG name — policies enforced by VFP on both VMs"
  value       = azurerm_network_security_group.demo5_nsg.name
}
