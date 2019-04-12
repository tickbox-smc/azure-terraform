locals {
    web_server_name            = "${var.environment == "production" ? "${var.web_server_name}-prod" : "${var.web_server_name}-dev"}"
    build_environment          = "${var.environment == "production" ? "production" : "development"}"
}
#resource group - A container that holds related resources for an Azure solution. The resource group includes those resources that you want to manage as a group. You decide how to allocate resources to resource groups based on what makes the most sense for your organization. See Resource groups.
resource "azurerm_resource_group" "web_server_rg" {
  name     = "${var.web_server_rg}"
  location = "${var.web_server_location}"

  tags {
      environment  = "${local.build_environment}"
      build_version = "${var.terraform_script_version}"
  }
}

resource "azurerm_virtual_network" "web_server_vnet" {
    name                                = "${var.resource_prefix}-vnet"
    location                            = "${var.web_server_location}"
    resource_group_name     = "${azurerm_resource_group.web_server_rg.name}"
    address_space                 = ["${var.web_server_address_space}"]

    lifecycle {
        prevent_destroy = true
    }
}

resource "azurerm_subnet" "web_server_subnet" {
    name                                    = "${var.resource_prefix}-${substr(var.web_server_subnets[count.index], 0, length(var.web_server_subnets[count.index]) - 3 )}-subnet"
    resource_group_name        = "${azurerm_resource_group.web_server_rg.name}"
    virtual_network_name         = "${azurerm_virtual_network.web_server_vnet.name}"
    address_prefix                     = "${var.web_server_subnets[count.index]}"
    network_security_group_id = "${count.index == 0 ? "${azurerm_network_security_group.web_server_nsg.id}" : "" }"
    count                                   = "${length(var.web_server_subnets)}"
}

# Removed as created as part of scale set
# resource "azurerm_network_interface" "web_server_nic" {
#     name                                 = "${var.web_server_name}-${format("%02d", count.index)}-nic"
#     location                             = "${var.web_server_location}"
#     resource_group_name     = "${azurerm_resource_group.web_server_rg.name}"
#     count                                 = "${var.web_server_count}"


#     ip_configuration {
#         name                                        = "${var.web_server_name}-${format("%02d", count.index)}-ip"
#         # This isn't great as in a real set up 
#         subnet_id                                 = "${azurerm_subnet.web_server_subnet.*.id[count.index]}"
#         private_ip_address_allocation = "dynamic"
#         # Associate the public ip with this nic
#         public_ip_address_id               = "${azurerm_public_ip.web_server_public_ip.*.id[count.index]}"
#     }
# }

resource "azurerm_public_ip" "web_server_lb_public_ip" {
    name                                        = "${var.resource_prefix}-public-ip"
    location                                    = "${var.web_server_location}"
    resource_group_name            = "${azurerm_resource_group.web_server_rg.name}"
    public_ip_address_allocation = "${var.environment == "production" ? "static" : "dynamic"}"
    domain_name_label                = "${var.domain_name_label}"
}

# Network Security Groups (NSG) = Security Group 
resource "azurerm_network_security_group" "web_server_nsg" {
    name                                      = "${var.resource_prefix}-nsg"
    location                                  = "${var.web_server_location}"
    resource_group_name           = "${azurerm_resource_group.web_server_rg.name}"
}

# Rules
resource "azurerm_network_security_rule" "web_server_nsg_rule_http" {
    name                                         = "RDP inbound"
    priority                                      = 100
    direction                                   = "Inbound"
    access                                      = "Allow"
    protocol                                    = "TCP"
    source_port_range                   = "*"
    destination_port_range            = "80"
    source_address_prefix             = "*"
    destination_address_prefix      = "*"
    resource_group_name              = "${azurerm_resource_group.web_server_rg.name}"
    network_security_group_name = "${azurerm_network_security_group.web_server_nsg.name}"
}

resource "azurerm_virtual_machine_scale_set" "web_server" {
    name                                      = "${var.resource_prefix}-scal-set"
    location                                  = "${var.web_server_location}"
    resource_group_name           = "${azurerm_resource_group.web_server_rg.name}"
    upgrade_policy_mode           = "manual"

    sku {
        name      = "Standard_B1s"
        tier          = "Standard"
        capacity = "${var.web_server_count}"
    }

    storage_profile_image_reference {
        publisher       = "MicrosoftWindowsServer"
        offer              = "WindowsServer"
        sku                = "2016-Datacenter-Server-Core-smalldisk"
        version          = "latest"
    }

    storage_profile_os_disk  {
        name                         = ""
        caching                     = "ReadWrite"
        create_option            =  "FromImage"
        managed_disk_type  = "Standard_LRS"
    }

    os_profile {
        computer_name_prefix         = "${local.web_server_name}"
        admin_username                  = "webserver"
        admin_password                  = "Passw0rd1234"
    }

    os_profile_windows_config {
        # This is required to have Terraform add the Azure VM Agent which enables us to provision instances # Not installed by default
        provision_vm_agent = true
    }

    network_profile{
        name     = "web_server_network_profile"
        primary = true

        ip_configuration {
            name = "${local.web_server_name}"
            primary = true
            subnet_id = "${azurerm_subnet.web_server_subnet.*.id[0]}"
            load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.web_server_lb_backend_pool.id}"]
        }
    }

    # This is required to have Terraform add the Azure VM Agent which enables us to provision instances # Not installed by default
    extension {
        name                               = "${local.web_server_name}-extension"
        publisher                        = "Microsoft.Compute"
        type                                = "CustomScriptExtension"
        type_handler_version     = "1.9"

        settings = <<SETTINGS
        {
            "fileUris": ["https://raw.githubusercontent.com/tickbox-smc/azure-play/master/azureInstallWebServer.ps1"],
            "commandToExecute": "start powershell -ExecutionPolicy Unrestricted -File azureInstallWebServer.ps1"
        }
        SETTINGS
    } 

}
# resource "azurerm_virtual_machine" "web_server" {
#     name                                      = "${var.web_server_name}-${format("%02d", count.index)}"
#     location                                  = "${var.web_server_location}"
#     resource_group_name           = "${azurerm_resource_group.web_server_rg.name}"
#     network_interface_ids           = ["${azurerm_network_interface.web_server_nic.*.id[count.index]}"]
#     vm_size                                  = "Standard_B1s"
#     count                                        = "${var.web_server_count}"
#     # Build the machine in the availability set
#     availability_set_id                   = "${azurerm_availability_set.web_server_availability_set.id}"
    
#     storage_image_reference {
#         publisher       = "MicrosoftWindowsServer"
#         offer              = "WindowsServer"
#         sku                = "2016-Datacenter-Server-Core-smalldisk"
#         version          = "latest"
#     }

#     storage_os_disk  {
#         name                         = "${var.web_server_name}-${format("%02d", count.index)}-os"
#         caching                     = "ReadWrite"
#         create_option            =  "FromImage"
#         managed_disk_type  = "Standard_LRS"
#     }

#     os_profile {
#         computer_name       = "${var.web_server_name}-${format("%02d", count.index)}"
#         admin_username      = "webserver"
#         admin_password      = "Passw0rd1234"
#     }

#     os_profile_windows_config {
#     }
# }

# resource "azurerm_availability_set" "web_server_availability_set" {
#     name                                        = "${var.resource_prefix}-availability-set"
#     location                                   = "${var.web_server_location}"
#     resource_group_name            = "${azurerm_resource_group.web_server_rg.name}"  
#     managed                                 = true
#     platform_fault_domain_count = 2
# }

resource "azurerm_lb" "web_server_lb" {
    name                                      = "${var.resource_prefix}-lb"
    location                                  = "${var.web_server_location}"
    resource_group_name           = "${azurerm_resource_group.web_server_rg.name}"

    frontend_ip_configuration {
        name                                      = "${var.resource_prefix}-lb-frontend-ip"
        public_ip_address_id             = "${azurerm_public_ip.web_server_lb_public_ip.id}"
    }
}

resource "azurerm_lb_backend_address_pool" "web_server_lb_backend_pool" {
    name                                      = "${var.resource_prefix}-lb-backend-pool"
    resource_group_name           = "${azurerm_resource_group.web_server_rg.name}"
    loadbalancer_id                     = "${azurerm_lb.web_server_lb.id}"
}

resource "azurerm_lb_probe" "web_server_lb_http_probe" {
     name                                      = "${var.resource_prefix}-lb-http-probe"
     resource_group_name           = "${azurerm_resource_group.web_server_rg.name}"
     loadbalancer_id                     = "${azurerm_lb.web_server_lb.id}"
     protocol                                 = "tcp"
     port                                       = "80"
}

resource "azurerm_lb_rule" "web_server_lb_http_rule" {
     name                                              = "${var.resource_prefix}-lb-http-rule"
     resource_group_name                  = "${azurerm_resource_group.web_server_rg.name}"
     loadbalancer_id                            = "${azurerm_lb.web_server_lb.id}"
     protocol                                        = "tcp"
     frontend_port                               = "80"
     backend_port                               = "80"
     frontend_ip_configuration_name = "${var.resource_prefix}-lb-frontend-ip"
     probe_id                                        = "${azurerm_lb_probe.web_server_lb_http_probe.id}"
     backend_address_pool_id           = "${azurerm_lb_backend_address_pool.web_server_lb_backend_pool.id}"
}