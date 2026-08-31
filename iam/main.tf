########################################################
# Samsung Cloud Platform v2 - Advance Landing Zone
########################################################

########################################################
# Provider : Samsung Cloud Platform v2
########################################################
terraform {
  required_providers {
    samsungcloudplatformv2 = {
      source  = "SamsungSDSCloud/samsungcloudplatformv2"
      version = "5.2.2"
    }
  }
  required_version = ">= 1.11"
}

provider "samsungcloudplatformv2" {
}

########################################################
# VPC (ceVPC, 10.0.0.0/16)
########################################################
resource "samsungcloudplatformv2_vpc_vpc" "vpc1" {
  name        = var.vpc_name
  cidr        = var.vpc_cidr
  description = var.vpc_description
  tags        = var.common_tags
}

########################################################
# Internet Gateway (ceVPC)
########################################################
resource "samsungcloudplatformv2_vpc_internet_gateway" "igw" {
  vpc_id            = samsungcloudplatformv2_vpc_vpc.vpc1.id
  type              = var.internet_gateway_type
  description       = "Internet Gateway for ${var.vpc_name}"
  firewall_enabled  = var.igw_firewall_enabled
  firewall_loggable = var.igw_firewall_loggable
  tags              = var.common_tags
}

########################################################
# Subnet
#  - websubnet 10.0.1.0/24 (PUBLIC)
#  - appsubnet 10.0.2.0/24 (PRIVATE)
#  - dbsubnet  10.0.3.0/24 (PRIVATE)
########################################################

# Public Subnet : websubnet (10.0.1.0/24) 
resource "samsungcloudplatformv2_vpc_subnet" "websubnet" {
  name        = var.websubnet_name
  cidr        = var.websubnet_cidr
  type        = "GENERAL"
  description = "Public subnet for web tier"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc1.id
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

# Private Subnet : appsubnet (10.0.2.0/24)
resource "samsungcloudplatformv2_vpc_subnet" "appsubnet" {
  name        = var.appsubnet_name
  cidr        = var.appsubnet_cidr
  type        = "GENERAL"
  description = "Private subnet for app tier"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc1.id
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

# Private Subnet : dbsubnet (10.0.3.0/24)
resource "samsungcloudplatformv2_vpc_subnet" "dbsubnet" {
  name        = var.dbsubnet_name
  cidr        = var.dbsubnet_cidr
  type        = "GENERAL"
  description = "Private subnet for db tier"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc1.id
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

########################################################
# Public IP (ceweb)
########################################################
resource "samsungcloudplatformv2_vpc_publicip" "web" {
  type        = var.internet_gateway_type
  description = "Public IP for ${var.vm_web.name}"
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_subnet.websubnet]
}

########################################################
# Security Group (webSG, appSG)
########################################################
resource "samsungcloudplatformv2_security_group_security_group" "web_sg" {
  name        = var.security_group_web
  description = "Security group for web tier"
  loggable    = false
  tags        = var.common_tags
}

resource "samsungcloudplatformv2_security_group_security_group" "app_sg" {
  name        = var.security_group_app
  description = "Security group for app tier"
  loggable    = false
  tags        = var.common_tags
}

########################################################
# Security Group Rule - webSG
########################################################
resource "samsungcloudplatformv2_security_group_security_group_rule" "web_ssh_in" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.user_public_ip
  description       = "SSH inbound from admin PC"
}

########################################################
# Firewall (Internet Gateway)
########################################################
data "samsungcloudplatformv2_firewall_firewalls" "igw" {
  product_type = [var.internet_gateway_type]
  vpc_name     = var.vpc_name
  size         = 1

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

locals {
  igw_firewall_id = try(data.samsungcloudplatformv2_firewall_firewalls.igw.ids[0], "")
}

########################################################
# Firewall Rule 
# Admin PC -> webvm SSH Inbound
########################################################
resource "samsungcloudplatformv2_firewall_firewall_rule" "web_ssh_in" {
  firewall_id = local.igw_firewall_id

  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    status              = "ENABLE"
    source_address      = [var.user_public_ip]
    destination_address = [var.vm_web.fixed_ip]
    description         = "SSH inbound to web server"
    service = [
      { service_type = "TCP", service_value = "22" }
    ]
  }
}

########################################################
# Key Pair
########################################################
resource "samsungcloudplatformv2_virtualserver_keypair" "kp" {
  name = var.keypair_name
  tags = var.common_tags
}

########################################################
# Standard Image 
########################################################
data "samsungcloudplatformv2_virtualserver_images" "os" {
  os_distro = var.image_os_distro
  status    = "active"

  filter {
    name      = "os_distro"
    values    = [var.image_os_distro]
    use_regex = false
  }

  filter {
    name      = "scp_os_version"
    values    = [var.image_scp_os_version]
    use_regex = false
  }
}

locals {
  image_ids = data.samsungcloudplatformv2_virtualserver_images.os.ids != null ? data.samsungcloudplatformv2_virtualserver_images.os.ids : []
  image_id  = length(local.image_ids) > 0 ? local.image_ids[0] : ""
}

########################################################
# Virtual Server : ceweb (websubnet, Public IP)
########################################################
resource "samsungcloudplatformv2_virtualserver_server" "webvm" {
  name           = var.vm_web.name
  state          = "ACTIVE"
  zone           = var.zone
  image_id       = local.image_id
  server_type_id = var.server_type_id
  keypair_name   = samsungcloudplatformv2_virtualserver_keypair.kp.name
  tags           = var.common_tags

  boot_volume = {
    size                  = var.boot_volume.size
    type                  = var.boot_volume.type
    delete_on_termination = var.boot_volume.delete_on_termination
  }

  networks = {
    nic0 = {
      subnet_id    = samsungcloudplatformv2_vpc_subnet.websubnet.id
      fixed_ip     = var.vm_web.fixed_ip
      public_ip_id = samsungcloudplatformv2_vpc_publicip.web.id
    }
  }

  security_groups = [samsungcloudplatformv2_security_group_security_group.web_sg.id]

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.websubnet,
    samsungcloudplatformv2_vpc_publicip.web,
    samsungcloudplatformv2_security_group_security_group.web_sg
  ]
}

########################################################
# Virtual Server : ceapp (appsubnet, Private)
########################################################
resource "samsungcloudplatformv2_virtualserver_server" "appvm" {
  name           = var.vm_app.name
  state          = "ACTIVE"
  zone           = var.zone
  image_id       = local.image_id
  server_type_id = var.server_type_id
  keypair_name   = samsungcloudplatformv2_virtualserver_keypair.kp.name
  tags           = var.common_tags

  boot_volume = {
    size                  = var.boot_volume.size
    type                  = var.boot_volume.type
    delete_on_termination = var.boot_volume.delete_on_termination
  }

  networks = {
    nic0 = {
      subnet_id = samsungcloudplatformv2_vpc_subnet.appsubnet.id
      fixed_ip  = var.vm_app.fixed_ip
    }
  }

  security_groups = [samsungcloudplatformv2_security_group_security_group.app_sg.id]

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.appsubnet,
    samsungcloudplatformv2_security_group_security_group.app_sg
  ]
}

########################################################
# PostgreSQL Engine Version
########################################################
data "samsungcloudplatformv2_postgresql_engine_version" "pg" {}

locals {
  pg_engine_versions = data.samsungcloudplatformv2_postgresql_engine_version.pg.contents != null ? data.samsungcloudplatformv2_postgresql_engine_version.pg.contents : []

  pg_engine_candidates = [
    for v in local.pg_engine_versions : v
    if v.end_of_service == false && can(regex(var.postgresql_version_pattern, v.software_version))
  ]

  pg_engine_version_id = (
    var.postgresql_engine_version_id != "" ?
    var.postgresql_engine_version_id :
    (length(local.pg_engine_candidates) > 0 ? local.pg_engine_candidates[0].id : "")
  )
}

########################################################
# PostgreSQL(DBaaS) - dbsubnet
########################################################
resource "samsungcloudplatformv2_postgresql_cluster" "db" {
  name                    = var.postgresql_cluster_name
  instance_name_prefix    = var.postgresql_instance_name_prefix
  dbaas_engine_version_id = local.pg_engine_version_id
  subnet_id               = samsungcloudplatformv2_vpc_subnet.dbsubnet.id
  service_state           = "RUNNING"
  timezone                = var.database_timezone

  ha_enabled  = false
  nat_enabled = false

  allowable_ip_addresses = [var.appsubnet_cidr]

  init_config_option = {
    audit_enabled          = false
    database_encoding      = "UTF-8"
    database_locale        = "C"
    database_name          = var.database_name
    database_port          = var.database_port
    database_user_name     = var.database_user
    database_user_password = var.database_password

    backup_option = {
      retention_period_day     = var.database_backup_option.retention_period_day
      starting_time_hour       = var.database_backup_option.starting_time_hour
      archive_frequency_minute = var.database_backup_option.archive_frequency_minute
    }
  }

  instance_groups = [
    {
      role_type        = "ACTIVE"
      server_type_name = var.postgresql_server_type_name

      block_storage_groups = [
        {
          role_type   = "OS"
          volume_type = "SSD"
          size_gb     = 104
        },
        {
          role_type   = "DATA"
          volume_type = "SSD"
          size_gb     = 16
        }
      ]

      instances = [
        {
          role_type          = "ACTIVE"
          service_ip_address = var.postgresql_service_ip_address
        }
      ]
    }
  ]

  maintenance_option = {
    use_maintenance_option = false
    period_hour            = null
    starting_day_of_week   = null
    starting_time          = null
  }

  tags = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_subnet.dbsubnet]
}

########################################################
# IAM Policy (AdministratorAccess)
########################################################
data "samsungcloudplatformv2_iam_policies" "admin" {
  policy_name = var.iam_admin_policy_name
  size        = 100
}

locals {
  admin_policies = data.samsungcloudplatformv2_iam_policies.admin.policies != null ? data.samsungcloudplatformv2_iam_policies.admin.policies : []

  admin_policy_ids = [
    for p in local.admin_policies : p.id
    if p.policy_name == var.iam_admin_policy_name
  ]

  admin_policy_id = length(local.admin_policy_ids) > 0 ? local.admin_policy_ids[0] : ""
}

########################################################
# IAM User (alex, robert, scott, jeff, leonard)
########################################################
resource "samsungcloudplatformv2_iam_user" "users" {
  for_each = toset(var.iam_users)

  account_id  = var.iam_account_id
  user_name   = each.value
  password    = base64encode(var.iam_root_password)
  description = var.iam_user_description
}

########################################################
# IAM User Policy (AdministratorAccess)
########################################################
resource "samsungcloudplatformv2_iam_user_policy_bindings" "admin" {
  for_each = samsungcloudplatformv2_iam_user.users

  user_id    = each.value.user_id
  policy_ids = [local.admin_policy_id]
}
