########################################################
# Output 
########################################################
output "vpc_info" {
  description = "VPC 정보"
  value = {
    id   = samsungcloudplatformv2_vpc_vpc.vpc1.id
    name = samsungcloudplatformv2_vpc_vpc.vpc1.name
    cidr = samsungcloudplatformv2_vpc_vpc.vpc1.cidr
  }
}

output "internet_gateway_info" {
  description = "Internet Gateway 및 Firewall 정보"
  value = {
    id          = samsungcloudplatformv2_vpc_internet_gateway.igw.id
    type        = samsungcloudplatformv2_vpc_internet_gateway.igw.type
    firewall_id = local.igw_firewall_id
  }
}

output "subnet_info" {
  description = "Subnet 정보"
  value = {
    websubnet = {
      id   = samsungcloudplatformv2_vpc_subnet.websubnet.id
      cidr = samsungcloudplatformv2_vpc_subnet.websubnet.cidr
      type = samsungcloudplatformv2_vpc_subnet.websubnet.type
    }
    appsubnet = {
      id   = samsungcloudplatformv2_vpc_subnet.appsubnet.id
      cidr = samsungcloudplatformv2_vpc_subnet.appsubnet.cidr
      type = samsungcloudplatformv2_vpc_subnet.appsubnet.type
    }
    dbsubnet = {
      id   = samsungcloudplatformv2_vpc_subnet.dbsubnet.id
      cidr = samsungcloudplatformv2_vpc_subnet.dbsubnet.cidr
      type = samsungcloudplatformv2_vpc_subnet.dbsubnet.type
    }
  }
}

output "security_group_info" {
  description = "Security Group 정보"
  value = {
    webSG = samsungcloudplatformv2_security_group_security_group.web_sg.id
    appSG = samsungcloudplatformv2_security_group_security_group.app_sg.id
  }
}

output "keypair_info" {
  description = "생성된 Key Pair 정보"
  value = {
    name        = samsungcloudplatformv2_virtualserver_keypair.kp.name
    fingerprint = samsungcloudplatformv2_virtualserver_keypair.kp.fingerprint
    public_key  = samsungcloudplatformv2_virtualserver_keypair.kp.public_key
  }
}

output "keypair_private_key" {
  description = "Key Pair 개인키. 생성 시점에만 확인 가능하므로 즉시 파일로 저장하십시오."
  value       = samsungcloudplatformv2_virtualserver_keypair.kp.private_key
  sensitive   = true
}

output "virtual_server_info" {
  description = "Virtual Server 정보"
  value = {
    webvm = {
      id           = samsungcloudplatformv2_virtualserver_server.webvm.id
      name         = samsungcloudplatformv2_virtualserver_server.webvm.name
      subnet       = "websubnet"
      private_ip   = var.vm_web.fixed_ip
      public_ip_id = samsungcloudplatformv2_vpc_publicip.web.id
      public_ip    = samsungcloudplatformv2_vpc_publicip.web.publicip.ip_address
    }
    appvm = {
      id         = samsungcloudplatformv2_virtualserver_server.appvm.id
      name       = samsungcloudplatformv2_virtualserver_server.appvm.name
      subnet     = "appsubnet"
      private_ip = var.vm_app.fixed_ip
    }
  }
}

output "postgresql_info" {
  description = "PostgreSQL(DBaaS) 정보"
  value = {
    id                = samsungcloudplatformv2_postgresql_cluster.db.id
    name              = var.postgresql_cluster_name
    subnet            = "dbsubnet"
    service_ip        = var.postgresql_service_ip_address
    port              = var.database_port
    database_name     = var.database_name
    engine_version_id = local.pg_engine_version_id
  }
}

output "iam_user_info" {
  description = "생성된 IAM User"
  value = {
    for name, u in samsungcloudplatformv2_iam_user.users : name => u.user_id
  }
}

output "iam_admin_policy_id" {
  description = "IAM User 에 연결된 정책 ID"
  value       = local.admin_policy_id
}
