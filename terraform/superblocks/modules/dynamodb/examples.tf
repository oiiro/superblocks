# --- examples.tf ---
# Example usage of the DynamoDB module
# Copy these examples to your main configuration file

# ==============================================================================
# SIMPLE EXAMPLE - Users Table
# ==============================================================================

module "users_table" {
  source = "./modules/dynamodb"

  table_name         = "users"
  hash_key           = "user_id"
  range_key          = "created_at"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task-role"
}

# ==============================================================================
# SIMPLE EXAMPLE - Transactions Table
# ==============================================================================

module "transactions_table" {
  source = "./modules/dynamodb"

  table_name         = "transactions"
  hash_key           = "txn_id"
  range_key          = "timestamp"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task-role"
}

# ==============================================================================
# NO RANGE KEY EXAMPLE - Sessions Table
# ==============================================================================

module "sessions_table" {
  source = "./modules/dynamodb"

  table_name = "sessions"
  hash_key   = "session_id"
  # No range_key specified
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task-role"
}

# ==============================================================================
# NUMBER KEY EXAMPLE - Products Table
# ==============================================================================

module "products_table" {
  source = "./modules/dynamodb"

  table_name         = "products"
  hash_key           = "product_id"
  hash_key_type      = "N" # Number type instead of String
  range_key          = "category"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task-role"
}

# ==============================================================================
# COMPLETE EXAMPLE - Multiple Tables
# ==============================================================================

module "orders_table" {
  source             = "./modules/dynamodb"
  table_name         = "orders"
  hash_key           = "order_id"
  range_key          = "created_at"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task-role"
}

module "customers_table" {
  source             = "./modules/dynamodb"
  table_name         = "customers"
  hash_key           = "customer_id"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task-role"
}

module "inventory_table" {
  source             = "./modules/dynamodb"
  table_name         = "inventory"
  hash_key           = "sku"
  range_key          = "warehouse_id"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task-role"
}

# ==============================================================================
# MULTIPLE ROLES EXAMPLE - Grant Access to ECS + Bastion
# ==============================================================================

module "admin_table" {
  source = "./modules/dynamodb"

  table_name         = "admin-logs"
  hash_key           = "log_id"
  range_key          = "timestamp"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"

  # Grant access to bastion host for debugging/administration
  additional_role_names = [
    "superblocks-dev-bastion-role"
  ]
}

# Multiple additional roles
module "shared_data_table" {
  source = "./modules/dynamodb"

  table_name         = "shared-data"
  hash_key           = "data_id"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"

  # Grant access to multiple roles (bastion, lambda, etc.)
  additional_role_names = [
    "superblocks-dev-bastion-role",
    "data-processing-lambda-role",
    "analytics-service-role"
  ]
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "dynamodb_tables" {
  description = "All DynamoDB table names"
  value = {
    users        = module.users_table.table_name
    transactions = module.transactions_table.table_name
    sessions     = module.sessions_table.table_name
    products     = module.products_table.table_name
    orders       = module.orders_table.table_name
    customers    = module.customers_table.table_name
    inventory    = module.inventory_table.table_name
  }
}

output "dynamodb_arns" {
  description = "All DynamoDB table ARNs"
  value = {
    users        = module.users_table.table_arn
    transactions = module.transactions_table.table_arn
    sessions     = module.sessions_table.table_arn
    products     = module.products_table.table_arn
    orders       = module.orders_table.table_arn
    customers    = module.customers_table.table_arn
    inventory    = module.inventory_table.table_arn
  }
}
