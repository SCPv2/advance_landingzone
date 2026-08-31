########################################################
# 사용자 입력
# 아래 두 변수의 실제 값을 입력하세요.
# your_public _ip : 실습자가 사용하고 있는 PC의 Public IP 주소
# your_account_id : 실습자가 접속하고 있는 Samsung Cloud Platform의 Account ID
########################################################

variable "user_public_ip" {
  type    = string
  default = "your_public_ip"
}

variable "iam_account_id" {
  type    = string
  default = "your_account_id"
}

########################################################
# Common 
########################################################
variable "common_tags" {
  type = map(string)
  default = {
    name      = "advance_landingzone"
    createdby = "terraform"
  }
}

variable "zone" {
  type    = string
  default = "kr-west1-b"
}

variable "keypair_name" {
  type    = string
  default = "mykey"
}

########################################################
# VPC / Internet Gateway
########################################################
variable "vpc_name" {
  type    = string
  default = "ceVPC"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vpc_description" {
  type    = string
  default = "Landing zone VPC"
}

variable "internet_gateway_type" {
  type    = string
  default = "IGW"

  validation {
    condition     = contains(["IGW", "GGW", "SIGW"], var.internet_gateway_type)
    error_message = "internet_gateway_type 은 IGW, GGW, SIGW"
  }
}

variable "igw_firewall_enabled" {
  type    = bool
  default = true
}

variable "igw_firewall_loggable" {
  type    = bool
  default = false
}

########################################################
# Subnet
########################################################
variable "websubnet_name" {
  type    = string
  default = "websubnet"
}

variable "websubnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "appsubnet_name" {
  type    = string
  default = "appsubnet"
}

variable "appsubnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "dbsubnet_name" {
  type    = string
  default = "dbsubnet"
}

variable "dbsubnet_cidr" {
  type    = string
  default = "10.0.3.0/24"
}

########################################################
# Security Group
########################################################
variable "security_group_web" {
  type    = string
  default = "webSG"
}

variable "security_group_app" {
  type    = string
  default = "appSG"
}

variable "web_service_port" {
  type    = number
  default = 80
}

variable "app_service_port" {
  type    = number
  default = 3000
}

variable "keycloak_port" {
  type    = number
  default = 8080
}

########################################################
# Virtual Server
########################################################
variable "server_type_id" {
  type    = string
  default = "s2v1m2"
}

variable "vm_web" {
  type = object({
    name     = string
    fixed_ip = string
  })
  default = {
    name     = "ceweb"
    fixed_ip = "10.0.1.11"
  }
}

variable "vm_app" {
  type = object({
    name     = string
    fixed_ip = string
  })
  default = {
    name     = "ceapp"
    fixed_ip = "10.0.2.21"
  }
}

variable "boot_volume" {
  type = object({
    size                  = number
    type                  = optional(string)
    delete_on_termination = optional(bool)
  })
  default = {
    size                  = 16
    type                  = "SSD"
    delete_on_termination = true
  }
}

variable "image_os_distro" {
  type    = string
  default = "rocky"
}

variable "image_scp_os_version" {
  type    = string
  default = "9.6"
}

########################################################
# PostgreSQL(DBaaS)
########################################################
variable "postgresql_cluster_name" {
  type    = string
  default = "cedbcluster"
}

variable "postgresql_instance_name_prefix" {
  type    = string
  default = "cedb"
}

variable "postgresql_engine_version_id" {
  type    = string
  default = ""
}

variable "postgresql_version_pattern" {
  type    = string
  default = "COMMUNITY 16"
}

variable "postgresql_server_type_name" {
  type    = string
  default = "db1v2m4"
}

variable "postgresql_service_ip_address" {
  type    = string
  default = "10.0.3.31"
}

variable "database_name" {
  type    = string
  default = "cedb"
}

variable "database_port" {
  type    = number
  default = 2866
}

variable "database_user" {
  type    = string
  default = "cedbadmin"
}

variable "database_password" {
  type      = string
  default   = "cedbadmin123!"
  sensitive = true
}

variable "database_timezone" {
  type    = string
  default = "Asia/Seoul"
}

variable "database_backup_option" {
  type = object({
    retention_period_day     = string
    starting_time_hour       = string
    archive_frequency_minute = string
  })
  default = {
    retention_period_day     = "7"
    starting_time_hour       = "12"
    archive_frequency_minute = "60"
  }
}

########################################################
# IAM
########################################################
variable "iam_users" {
  type    = list(string)
  default = ["Alex", "Robert", "Scott", "Jeff", "Leonard"]
}

variable "iam_root_password" {
  type    = string
  default = "Changeit1!"
}

variable "iam_user_description" {
  type    = string
  default = "Creative Energy User"
}

variable "iam_admin_policy_name" {
  type    = string
  default = "AdministratorAccess"
}
