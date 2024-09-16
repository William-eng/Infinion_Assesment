terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.2.0"
    }
  }
}

provider "azurerm" {
    features {}
    subscription_id = "010a4609-7f98-4bd9-8b5f-3d6853a53cb5"
    tenant_id       = "215b7ce2-5263-4593-a622-da030405d151"
}


resource "azurerm_resource_group" "apache_terraform_rg" {
  name     = var.resource_group_name
  location = var.location

  lifecycle {
    prevent_destroy = false
  }
}

resource "azurerm_virtual_network" "apache_terraform_vnet" {
  name                = var.virtual_network_name
  location            = var.location
  address_space       = var.address_space
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name
}

#Create subnet to the virtual network

resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}_subnet"
  virtual_network_name = azurerm_virtual_network.apache_terraform_vnet.name
  resource_group_name  = azurerm_resource_group.apache_terraform_rg.name
  address_prefixes     = var.subnet_prefix
}

#Create public ip
resource "azurerm_public_ip" "apache_terraform_pip" {
  name                = "${var.prefix}-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

#Create Network security group
resource "azurerm_network_security_group" "apache_terraform_sg" {
  name                = "${var.prefix}-sg"
  location            = var.location
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name

  security_rule {
    name                       = "HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_network_interface" "apache_terraform_nic" {
  name                = "${var.prefix}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name

  ip_configuration {
    name                          = "${var.prefix}-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.apache_terraform_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "my-nsg-assoc" {
  network_interface_id      = azurerm_network_interface.apache_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.apache_terraform_sg.id
}

# Create (and display) an SSH key
resource "tls_private_key" "secureadmin_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


#Create VM

resource "azurerm_virtual_machine" "apache_terraform_site" {
  name                = "${var.hostname}-site"
  location            = var.location
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name
  vm_size             = var.vm_size


  # admin_ssh_key {
  #    username   = var.admin_username
  #    public_key = tls_private_key.secureadmin_ssh.public_key_openssh
  # }

  network_interface_ids         = ["${azurerm_network_interface.apache_terraform_nic.id}"]
  delete_os_disk_on_termination = "true"

  storage_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  storage_os_disk {
    name              = "${var.hostname}_osdisk"
    managed_disk_type = "Standard_LRS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = var.hostname
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data = <<-EOT
      #!/bin/bash
      "sudo apt install apache2 -y && sudo systemctl start apache2",
      "sudo apt install git  -y",
      "git clone https://github.com/devopsthepracticalway/bootcamp-1-project-1a.git ",
      "sudo mv bootcamp-1-project-1a/* /var/www/html/"
        EOT
  }
  

  


 os_profile_linux_config {
   disable_password_authentication = true
   ssh_keys {
     path     = "/home/${var.admin_username}/.ssh/authorized_keys"
     key_data = file("~/.ssh/id_rsa.pub")
   }
   

 }

 }
 
 

#resource "azurerm_resource_group" "infinion_cdn" {
#  name     = "my-resource"
#  location = var.location
#}

#resource "azurerm_cdn_profile" "infinion" {
#  name                = "Infinion-cdn"
#  location            = azurerm_resource_group.infinion_cdn.location
#  resource_group_name = azurerm_resource_group.infinion_cdn.name
#  sku                 = "Standard_Verizon"
#}

#resource "azurerm_cdn_endpoint" "infinioncdn" {
#  name                = "infiendpoint"
#  profile_name        = azurerm_cdn_profile.infinion.name
#  location            = azurerm_resource_group.infinion_cdn.location
#  resource_group_name = azurerm_resource_group.infinion_cdn.name

#  origin {
#    name      = "willlyinfinion"
#    host_name = "www.infiweb.com"
#  }
#}
# resource  "null_resource" "example" {
#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt install apache2 -y && sudo systemctl start apache2",
#       "sudo apt install git  -y",
#       "git clone https://github.com/devopsthepracticalway/bootcamp-1-project-1a.git ",
#       "sudo mv bootcamp-1-project-1a/* /var/www/html/"
#     ]
#     connection {
#       type        = "ssh"
#       host        = azurerm_public_ip.apache_terraform_pip.fqdn
#       user        = var.admin_username
#       private_key = file("~/.ssh/id_rsa")
#     }
   

   
    
#   }

#  }