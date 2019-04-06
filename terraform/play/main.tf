provider "azurerm" {
    version                 = "1.16"
    #client_id               = "ead5f3e6-44b9-4e74-b2ac-e1b1b8f6e275"
    #client_secret        =   "YX6rFoXsEaoj2q6JzKbqb+T/q+7vyJc9u1JuWqfHs3E="
    #tenant_id           =  "1967a449-d2f3-4a81-b1f6-64ceaa0ace00"
    #subscription_id   = "44ee1323-00ce-4b4f-bcf2-d279a3d621b1"
}

#resource group - A container that holds related resources for an Azure solution. The resource group includes those resources that you want to manage as a group. You decide how to allocate resources to resource groups based on what makes the most sense for your organization. See Resource groups.
resource "azurerm_resource_group" "web_server_rg" {
  name     = "${var.web_server_rg}"
  location = "${var.web_server_location}"
}

resource "azurerm_virtual_network" "web_server_vnet" {
    name                                = "${var.resource_prefix}-vnet"
    location                            = "${var.web_server_location}"
    resource_group_name     = "${azurerm_resource_group.web_server_rg.name}"
    address_space                 = ["${var.web_server_address_space}"]
}

resource "azurerm_subnet" "web_server_subnet" {
    name                                = "${var.resource_prefix}-subnet"
    resource_group_name    = "${azurerm_resource_group.web_server_rg.name}"
    virtual_network_name     = "${azurerm_virtual_network.web_server_vnet.name}"
    address_prefix                 = "${var.web_server_address_prefix}"
}

resource "azurerm_network_interface" "web_server_nic" {
    name                                = "${var.web_server_name}-nic"
    location                            = "${var.web_server_location}"
    resource_group_name     = "${azurerm_resource_group.web_server_rg.name}"

    # Associate the NSG with this network interface
    network_security_group_id = "${azurerm_network_security_group.web_server_nsg.id}"

    ip_configuration {
        name                                        = "${var.web_server_name}-ip"
        subnet_id                                 = "${azurerm_subnet.web_server_subnet.id}"
        private_ip_address_allocation = "dynamic"
        # Associate the public ip with this nic
        public_ip_address_id               = "${azurerm_public_ip.web_server_public_ip.id}"
    }
}

resource "azurerm_public_ip" "web_server_public_ip" {
    name                                      = "${var.web_server_name}-public-ip"
    location                                  = "${var.web_server_location}"
    resource_group_name           = "${azurerm_resource_group.web_server_rg.name}"
    public_ip_address_allocation = "${var.environment == "production" ? "static" : "dynamic"}"
}

# Network Security Groups (NSG) = Security Group 
resource "azurerm_network_security_group" "web_server_nsg" {
    name                                      = "${var.web_server_name}-nsg"
    location                                  = "${var.web_server_location}"
    resource_group_name           = "${azurerm_resource_group.web_server_rg.name}"
}

# Rules
resource "azurerm_network_security_rule" "web_server_nsg_rule_rdp" {
    name = "RDP inbound"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol  = "TCP"
    source_port_range = "*"
    destination_port_range = "3389"
    source_address_prefix = "*"
    destination_address_prefix = "*"
    resource_group_name           = "${azurerm_resource_group.web_server_rg.name}"
    network_security_group_name = "${azurerm_network_security_group.web_server_nsg.name}"

}

resource "azurerm_virtual_machine" "web_server" {
    name                                      = "${var.web_server_name}"
    location                                  = "${var.web_server_location}"
    resource_group_name           = "${azurerm_resource_group.web_server_rg.name}"
    network_interface_ids           = ["${azurerm_network_interface.web_server_nic.id}"]
    vm_size                                  = "Standard_B1s"

    # Build the machine in the availability set
    availability_set_id                   = "${azurerm_availability_set.web_server_availability_set.id}"
    
    storage_image_reference {
        publisher       = "MicrosoftWindowsServer"
        offer              = "WindowsServer"
        sku                = "2016-Datacenter-Server-Core-smalldisk"
        version          = "latest"
    }

    storage_os_disk  {
        name                         = "${var.web_server_name}-os"
        caching                     = "ReadWrite"
        create_option            =  "FromImage"
        managed_disk_type  = "Standard_LRS"
    }

    os_profile {
        computer_name       = "${var.web_server_name}"
        admin_username      = "webserver"
        admin_password      = "Passw0rd1234"
    }

    os_profile_windows_config {
    }
}

resource "azurerm_availability_set" "web_server_availability_set" {
    name                                        = "${var.resource_prefix}-availability-set"
    location                                   = "${var.web_server_location}"
    resource_group_name            = "${azurerm_resource_group.web_server_rg.name}"  
    managed                                 = true
    platform_fault_domain_count = 2
}
