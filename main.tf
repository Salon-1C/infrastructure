locals {
  ecr_repository_names = [
    "blume-backend",
    "stream-engine",
    "record-service",
    "blume-wa",
    "activities-ms",
    "recommendations-ms",
    "blume-mediamtx",
  ]

  github_repos = [
    "infrastructure",
    "blume_business_logic_ms",
    "blume_stream_ms",
    "blume_record_ms",
    "blume_wa",
    "blume_stream_activities_ms",
    "blume_recomendations_ms",
  ]
}

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
  github_repos          = local.github_repos
  ecr_repository_names  = local.ecr_repository_names
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

module "rds_activities" {
  source             = "./modules/rds"
  project            = "${var.project}-activities"
  engine             = "postgres"
  db_name            = var.activities_db_name
  username           = var.activities_db_user
  db_instance_class  = var.activities_db_instance_class
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

  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  alb_sg_id          = module.networking.alb_sg_id
  ecs_sg_id          = module.networking.ecs_sg_id

  ecs_task_execution_role_arn   = module.iam.ecs_task_execution_role_arn
  business_logic_task_role_arn  = module.iam.business_logic_task_role_arn
  stream_engine_task_role_arn   = module.iam.stream_engine_task_role_arn
  record_service_task_role_arn  = module.iam.record_service_task_role_arn
  activities_task_role_arn      = module.iam.activities_task_role_arn
  recommendations_task_role_arn = module.iam.recommendations_task_role_arn
  frontend_task_role_arn        = module.iam.frontend_task_role_arn

  blume_backend_image_url      = module.ecr.blume_backend_url
  stream_engine_image_url      = module.ecr.stream_engine_url
  record_service_image_url     = module.ecr.record_service_url
  blume_wa_image_url           = module.ecr.blume_wa_url
  activities_ms_image_url      = module.ecr.activities_ms_url
  recommendations_ms_image_url = module.ecr.recommendations_ms_url
  mediamtx_image_url           = module.ecr.mediamtx_url

  db_host                = module.rds.host
  db_name                = var.db_name
  db_password_secret_arn = module.rds.db_password_secret_arn

  activities_db_host                = module.rds_activities.host
  activities_db_name                = var.activities_db_name
  activities_db_user                = var.activities_db_user
  activities_db_password_secret_arn = module.rds_activities.db_password_secret_arn

  recordings_db_host                = module.rds_recordings.host
  recordings_db_name                = var.recordings_db_name
  recordings_db_password_secret_arn = module.rds_recordings.db_password_secret_arn
  recordings_bucket_name            = module.s3_recordings.bucket_name

  jwt_secret                    = var.jwt_secret
  hls_signing_secret            = var.hls_signing_secret
  firebase_service_account_json = var.firebase_service_account_json
  stream_key                    = var.stream_key
  activities_secret_key_base    = var.activities_secret_key_base

  mail_host     = var.mail_host
  mail_port     = var.mail_port
  mail_username = var.mail_username

  allowed_origin = var.allowed_origin
  public_app_url = var.public_app_url

  business_logic_desired_count  = var.business_logic_desired_count
  stream_engine_desired_count   = var.stream_engine_desired_count
  record_service_desired_count  = var.record_service_desired_count
  activities_desired_count      = var.activities_desired_count
  recommendations_desired_count = var.recommendations_desired_count
  frontend_desired_count        = var.frontend_desired_count
}

module "api_gateway" {
  source             = "./modules/api_gateway"
  project            = var.project
  private_subnet_ids = module.networking.private_subnet_ids
  alb_sg_id          = module.networking.alb_sg_id
  alb_listener_arn   = module.ecs.alb_listener_arn
}
