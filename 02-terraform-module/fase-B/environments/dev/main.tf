module "network" {
    source = "../../modules/network"
    project_id = var.project_id
    env = var.env
    application_name = var.application_name
    region = var.region
    subnet_ip_range = var.subnet_ip_range
}
module "compute" {
    source = "../../modules/compute"
    project_id = var.project_id
    env = var.env
    application_name = var.application_name
    image_family = var.image_family
    zone = var.zone
    network_id = module.network.network_id
    subnet_id = module.network.subnet_id
    startup_script  = templatefile("${path.module}/startup-script.sh.tpl", { image_tag = var.stable_image_tag })
    machine_type = var.machine_type
    target_size = var.target_size
    canary_startup_script  = var.canary_instance_count > 0 ? templatefile("${path.module}/startup-script.sh.tpl", { image_tag = var.canary_image_tag }) : null
    canary_instance_count  = var.canary_instance_count
}

module "sql" {
  source                    = "../../modules/sql"
  project_id                 = var.project_id
  env                        = var.env
  application_name           = var.application_name
  region                     = var.region
  db_version                 = var.db_version
  db_edition                 = var.db_edition
  db_tier                    = var.db_tier
  db_deletion_protection     = var.db_deletion_protection
  db_ipv4_enabled            = var.db_ipv4_enabled
  db_backup_enabled          = var.db_backup_enabled
  db_backup_location         = var.db_backup_location
  db_binary_log_enabled      = var.db_binary_log_enabled
  db_backup_start_time       = var.db_backup_start_time
  db_transaction_log_retention_days = var.db_transaction_log_retention_days
  network_id                 = module.network.network_id
  private_vpc_connection_id = module.network.private_vpc_connection_id
  db_point_in_time_recovery_enabled = var.db_point_in_time_recovery_enabled
  vm_service_account_email  = module.compute.service_account_email
}

module "loadbalancer" {
  source         = "../../modules/loadbalancer"
  project_id     = var.project_id
  env            = var.env
  application_name = var.application_name
  instance_group = module.compute.instance_group
  security_policy_id  = module.armor.security_policy_id
}

module "armor" {
  source     = "../../modules/armor"
  project_id = var.project_id
  env        = var.env
  application_name = var.application_name
}

module "monitoring" {
  source              = "../../modules/monitoring"
  project_id          = var.project_id
  env                 = var.env
  application_name    = var.application_name
  host                = module.loadbalancer.load_balancer_ip
  notification_email  = var.alert_email
}