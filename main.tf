terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.0.0"
    }
  }
}
provider "azurerm" {
  features {}

}
resource "azurerm_resource_group" "arnabrg" {
  name     = "arnabrg"
  location = "West Europe"
  tags = {
    "environment" = "dev"
  }
}
resource "azurerm_virtual_network" "arnab-vn" {
  name                = "arnabvn"
  resource_group_name = azurerm_resource_group.arnabrg.name
  location            = azurerm_resource_group.arnabrg.location
  address_space       = ["10.123.0.0/16"]
  tags = {
    "environment" = "dev"
  }

}
resource "azurerm_subnet" "arnab-snet" {
  name                 = "arnab-subnet"
  resource_group_name  = azurerm_resource_group.arnabrg.name
  virtual_network_name = azurerm_virtual_network.arnab-vn.name
  address_prefixes     = ["10.123.1.0/24"]

}
resource "azurerm_network_security_group" "arnab-nsg" {
  name                = "arnab-netsg"
  resource_group_name = azurerm_resource_group.arnabrg.name
  location            = azurerm_resource_group.arnabrg.location
  tags = {
    "environment" = "dev"
  }

}
resource "azurerm_network_security_rule" "arnab-srule" {
  name                        = "arnab-security-rule"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.arnabrg.name
  network_security_group_name = azurerm_network_security_group.arnab-nsg.name
}
resource "azurerm_subnet_network_security_group_association" "arnab-nsg-assosiation" {
  subnet_id                 = azurerm_subnet.arnab-snet.id
  network_security_group_id = azurerm_network_security_group.arnab-nsg.id

}
resource "azurerm_public_ip" "public_ip" {
  name                = "arnab-public-ip"
  resource_group_name = azurerm_resource_group.arnabrg.name
  location            = azurerm_resource_group.arnabrg.location
  allocation_method   = "Dynamic"
  tags = {
    "environment" = "dev"
  }
}

resource "azurerm_network_interface" "arnab-nic" {
  name                = "arnab-network-interface"
  location            = azurerm_resource_group.arnabrg.location
  resource_group_name = azurerm_resource_group.arnabrg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.arnab-snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
  tags = {
    "environment" = "dev"
  }
}

# resource "azurerm_virtual_machine" "arnab-vm" {
#   name                  = "arnab-vm"
#   location              = azurerm_resource_group.arnabrg.location
#   resource_group_name   = azurerm_resource_group.arnabrg.name
#   network_interface_ids = [azurerm_network_interface.arnab-nic.id]
#   vm_size               = "Standard_DS1_v2"

#   storage_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "16.04-LTS"
#     version   = "latest"
#   }
#   storage_os_disk {
#     name              = "myosdisk1"
#     caching           = "ReadWrite"
#     create_option     = "FromImage"
#     managed_disk_type = "Standard_LRS"
#   }
#   os_profile {
#     computer_name  = "arnab-vm"
#     admin_username = "testadmin"
#     admin_password = "Password1234!"
#     custom_data    = filebase64("customdata.sh")
#   }
#   os_profile_linux_config {
#     disable_password_authentication = false
#     ssh_keys {
#       key_data = file("~/.ssh/arnabazurekey.pub")
#       path     = "/home/testadmin/.ssh/authorized_keys"
#     }
#   }
#   tags = {
#     environment = "dev"
#   }
# }
resource "azurerm_linux_virtual_machine" "arnab-azure-vm" {
  name                  = "arnab-azure-vm"
  resource_group_name   = azurerm_resource_group.arnabrg.name
  location              = azurerm_resource_group.arnabrg.location
  size                  = "Standard_F2"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.arnab-nic.id]
  custom_data           = filebase64("customdata.tpl")
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/arnabazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-sconfig.tpl", {
      hostname     = self.public_ip_address
      user         = "adminuser"
      identityfile = "~/.ssh/arnabazurekey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }
  tags = {
    "environment" = "dev"
  }
}
data "azurerm_public_ip" "public_ip_data" {
  name                = azurerm_public_ip.public_ip.name
  resource_group_name = azurerm_resource_group.arnabrg.name
}
output "output_ip" {
  value = "${azurerm_linux_virtual_machine.arnab-azure-vm.name}: ${data.azurerm_public_ip.public_ip_data.ip_address}"
}
variable "host_os" {
    type = string
  
}
