module "networking" {
  source   = "./modules/networking"
  project  = var.project
  vpc_cidr = "10.0.0.0/16"
}

module "ecr" {
  source  = "./modules/ecr"
  project = var.project
}

module "iam" {
  source                = "./modules/iam"
  project               = var.project
  github_org            = var.github_org
  github_repos          = ["business-logic", "stream-engine", "record-service"]
  recordings_bucket_arn = module.s3_recordings.bucket_arn
}

module "rds" {
  source             = "./modules/rds"
  project            = var.project
  db_name            = var.db_name
  db_instance_class  = var.db_instance_class
  private_subnet_ids = module.networking.private_subnet_ids
  rds_sg_id          = module.networking.rds_sg_id
}

module "rds_recordings" {
  source             = "./modules/rds"
  project            = "${var.project}-recordings"
  db_name            = var.recordings_db_name
  db_instance_class  = var.recordings_db_instance_class
  private_subnet_ids = module.networking.private_subnet_ids
  rds_sg_id          = module.networking.rds_sg_id
}

module "s3_recordings" {
  source      = "./modules/s3_recordings"
  project     = var.project
  bucket_name = var.recordings_bucket_name
}

module "ecs" {
  source  = "./modules/ecs"
  project = var.project

  # Networking
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  alb_sg_id          = module.networking.alb_sg_id
  ecs_sg_id          = module.networking.ecs_sg_id

  # IAM
  ecs_task_execution_role_arn  = module.iam.ecs_task_execution_role_arn
  business_logic_task_role_arn = module.iam.business_logic_task_role_arn
  stream_engine_task_role_arn  = module.iam.stream_engine_task_role_arn
  record_service_task_role_arn = module.iam.record_service_task_role_arn

  # ECR images
  blume_backend_image_url  = module.ecr.blume_backend_url
  stream_engine_image_url  = module.ecr.stream_engine_url
  record_service_image_url = module.ecr.record_service_url

  # RDS
  db_host                = module.rds.host
  db_name                = var.db_name
  db_password_secret_arn = module.rds.db_password_secret_arn

  recordings_db_host                = module.rds_recordings.host
  recordings_db_name                = var.recordings_db_name
  recordings_db_password_secret_arn = module.rds_recordings.db_password_secret_arn
  recordings_bucket_name            = module.s3_recordings.bucket_name

  # App secrets
  jwt_secret                    = var.jwt_secret
  hls_signing_secret            = var.hls_signing_secret
  firebase_service_account_json = var.firebase_service_account_json
  stream_key                    = var.stream_key

  # Mail
  mail_host     = var.mail_host
  mail_port     = var.mail_port
  mail_username = var.mail_username

  # App config
  allowed_origin               = var.allowed_origin
  business_logic_desired_count = var.business_logic_desired_count
  stream_engine_desired_count  = var.stream_engine_desired_count
  record_service_desired_count = var.record_service_desired_count
}

module "api_gateway" {
  source             = "./modules/api_gateway"
  project            = var.project
  private_subnet_ids = module.networking.private_subnet_ids
  alb_sg_id          = module.networking.alb_sg_id
  alb_listener_arn   = module.ecs.alb_listener_arn
}
