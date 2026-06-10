#########################################################
# Demo 4 – Load Balancer / SNAT Exhaustion
# Scenario: "It works… then suddenly fails under load."
# Shows: Outbound SNAT port behavior on Standard LB,
#        then compare with NAT Gateway as a cleaner fix.
# Key Takeaway: Illustrates intermittent outbound failures
#               and when NAT Gateway is the right fix.
#########################################################

#########################################################
# Resource Group
#########################################################

resource "azurerm_resource_group" "demo4_rg" {
  name     = "te-rg-demo4-snat-001"
  location = "westeurope"
}

#########################################################
# Virtual Network & Subnets
#########################################################

resource "azurerm_virtual_network" "demo4_vnet" {
  name                = "te-vnet-demo4-001"
  location            = azurerm_resource_group.demo4_rg.location
  resource_group_name = azurerm_resource_group.demo4_rg.name
  address_space       = ["10.230.0.0/16"]
}

resource "azurerm_subnet" "demo4_lb_subnet" {
  name                 = "te-snet-demo4-lb-001"
  resource_group_name  = azurerm_resource_group.demo4_rg.name
  virtual_network_name = azurerm_virtual_network.demo4_vnet.name
  address_prefixes     = ["10.230.1.0/24"]
}

resource "azurerm_subnet" "demo4_nat_subnet" {
  name                 = "te-snet-demo4-nat-001"
  resource_group_name  = azurerm_resource_group.demo4_rg.name
  virtual_network_name = azurerm_virtual_network.demo4_vnet.name
  address_prefixes     = ["10.230.2.0/24"]
}

#########################################################
# Standard Load Balancer with Outbound Rule
# Demonstrates: Limited SNAT port allocation per VM
#########################################################

resource "azurerm_public_ip" "demo4_lb_pip" {
  name                = "te-pip-lb-demo4-001"
  location            = azurerm_resource_group.demo4_rg.location
  resource_group_name = azurerm_resource_group.demo4_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "demo4_lb" {
  name                = "te-lb-demo4-001"
  location            = azurerm_resource_group.demo4_rg.location
  resource_group_name = azurerm_resource_group.demo4_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "lb-frontend"
    public_ip_address_id = azurerm_public_ip.demo4_lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "demo4_lb_backend" {
  name            = "te-bap-demo4-001"
  loadbalancer_id = azurerm_lb.demo4_lb.id
}

# Outbound rule with limited SNAT ports to demonstrate exhaustion
resource "azurerm_lb_outbound_rule" "demo4_outbound_rule" {
  name                    = "te-outbound-demo4-001"
  loadbalancer_id         = azurerm_lb.demo4_lb.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.demo4_lb_backend.id

  frontend_ip_configuration {
    name = "lb-frontend"
  }

  allocated_outbound_ports = 1024 # Low port count to demonstrate exhaustion
  idle_timeout_in_minutes  = 4
}

#########################################################
# NAT Gateway (the cleaner alternative for outbound)
# Provides ~64K SNAT ports per public IP, auto-scales
#########################################################

resource "azurerm_public_ip" "demo4_nat_pip" {
  name                = "te-pip-nat-demo4-001"
  location            = azurerm_resource_group.demo4_rg.location
  resource_group_name = azurerm_resource_group.demo4_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "demo4_nat_gw" {
  name                    = "te-natgw-demo4-001"
  location                = azurerm_resource_group.demo4_rg.location
  resource_group_name     = azurerm_resource_group.demo4_rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_association" "demo4_nat_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.demo4_nat_gw.id
  public_ip_address_id = azurerm_public_ip.demo4_nat_pip.id
}

resource "azurerm_subnet_nat_gateway_association" "demo4_nat_subnet_assoc" {
  subnet_id      = azurerm_subnet.demo4_nat_subnet.id
  nat_gateway_id = azurerm_nat_gateway.demo4_nat_gw.id
}

#########################################################
# VM in LB Backend Pool (demonstrates SNAT exhaustion)
#########################################################

resource "azurerm_network_interface" "demo4_lb_vm_nic" {
  name                = "te-nic-demo4-lb-vm-001"
  location            = azurerm_resource_group.demo4_rg.location
  resource_group_name = azurerm_resource_group.demo4_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo4_lb_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "demo4_lb_nic_assoc" {
  network_interface_id    = azurerm_network_interface.demo4_lb_vm_nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.demo4_lb_backend.id
}

resource "azurerm_linux_virtual_machine" "demo4_lb_vm" {
  name                            = "te-vm-demo4-lb-001"
  location                        = azurerm_resource_group.demo4_rg.location
  resource_group_name             = azurerm_resource_group.demo4_rg.name
  size                            = "Standard_B2s"
  admin_username                  = "azureuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.demo4_lb_vm_nic.id]

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
# VM in NAT Gateway Subnet (demonstrates cleaner outbound)
#########################################################

resource "azurerm_network_interface" "demo4_nat_vm_nic" {
  name                = "te-nic-demo4-nat-vm-001"
  location            = azurerm_resource_group.demo4_rg.location
  resource_group_name = azurerm_resource_group.demo4_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo4_nat_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "demo4_nat_vm" {
  name                            = "te-vm-demo4-nat-001"
  location                        = azurerm_resource_group.demo4_rg.location
  resource_group_name             = azurerm_resource_group.demo4_rg.name
  size                            = "Standard_B2s"
  admin_username                  = "azureuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.demo4_nat_vm_nic.id]

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
#   1. SSH into LB VM, run: for i in $(seq 1 2000); do curl -s -o /dev/null http://example.com & done
#   2. Show SNAT exhaustion in LB metrics (Metrics > SNAT Connection Count)
#   3. SSH into NAT VM, run same test — no failures
#########################################################

output "demo4_lb_public_ip" {
  description = "Load Balancer public IP (limited SNAT ports)"
  value       = azurerm_public_ip.demo4_lb_pip.ip_address
}

output "demo4_nat_gateway_public_ip" {
  description = "NAT Gateway public IP (~64K ports per IP)"
  value       = azurerm_public_ip.demo4_nat_pip.ip_address
}

output "demo4_lb_allocated_ports" {
  description = "SNAT ports allocated per VM via LB outbound rule"
  value       = azurerm_lb_outbound_rule.demo4_outbound_rule.allocated_outbound_ports
}

output "demo4_lb_vm_private_ip" {
  description = "LB backend VM private IP"
  value       = azurerm_network_interface.demo4_lb_vm_nic.private_ip_address
}

output "demo4_nat_vm_private_ip" {
  description = "NAT Gateway VM private IP"
  value       = azurerm_network_interface.demo4_nat_vm_nic.private_ip_address
}
