# DynamoDB Module - Quick Start

## 🚀 Step-by-Step Workflow

### Step 1: Start with One Table

Create or edit your `main.tf`:

```hcl
module "users_table" {
  source = "./modules/dynamodb"

  table_name         = "users"
  hash_key           = "user_id"
  range_key          = "created_at"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"  # ⚠️ NAME not ARN
}
```

**Important**: Use the **role NAME**, not the ARN:
- ✅ Correct: `"superblocks-ecs-task"`
- ❌ Wrong: `"arn:aws:iam::123456789012:role/superblocks-ecs-task"`

Deploy:
```bash
terraform init
terraform plan    # Review: will create 1 table + 1 IAM policy
terraform apply   # Type 'yes' to create
```

**What you get:**
- Table: `superblocksdemo-users`
- IAM policy: `superblocksdemo-users-XXXXX` attached to your ECS task role

---

### Step 2: Add Another Table

Add to your `main.tf`:

```hcl
module "users_table" {
  source             = "./modules/dynamodb"
  table_name         = "users"
  hash_key           = "user_id"
  range_key          = "created_at"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}

# ⬇️ NEW TABLE
module "transactions_table" {
  source             = "./modules/dynamodb"
  table_name         = "transactions"
  hash_key           = "txn_id"
  range_key          = "timestamp"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
```

Deploy the new table:
```bash
terraform plan    # Review: will create 1 NEW table + 1 NEW IAM policy
                 # Existing users_table unchanged ✓

terraform apply   # Type 'yes'
```

**What you get:**
- Table: `superblocksdemo-transactions` (NEW)
- IAM policy: `superblocksdemo-transactions-XXXXX` (NEW)
- Table: `superblocksdemo-users` (unchanged)

---

### Step 3: Add More Tables

Keep adding modules:

```hcl
module "users_table" {
  source = "./modules/dynamodb"
  table_name = "users"
  hash_key = "user_id"
  range_key = "created_at"
  app_name = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}

module "transactions_table" {
  source = "./modules/dynamodb"
  table_name = "transactions"
  hash_key = "txn_id"
  range_key = "timestamp"
  app_name = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}

# ⬇️ MORE TABLES
module "sessions_table" {
  source             = "./modules/dynamodb"
  table_name         = "sessions"
  hash_key           = "session_id"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
  # No range_key needed
}

module "products_table" {
  source             = "./modules/dynamodb"
  table_name         = "products"
  hash_key           = "product_id"
  hash_key_type      = "N"  # Number type
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
```

Deploy:
```bash
terraform plan    # Will show 2 new tables to create
terraform apply
```

---

### Step 4: Remove a Table

To remove a table, **delete its module block** from `main.tf`:

```hcl
module "users_table" {
  source = "./modules/dynamodb"
  table_name = "users"
  hash_key = "user_id"
  range_key = "created_at"
  app_name = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}

# ❌ DELETE THIS ENTIRE BLOCK to remove transactions table
# module "transactions_table" {
#   source = "./modules/dynamodb"
#   table_name = "transactions"
#   hash_key = "txn_id"
#   range_key = "timestamp"
#   app_name = "superblocksdemo"
#   ecs_task_role_name = "superblocks-ecs-task"
# }

module "sessions_table" {
  source = "./modules/dynamodb"
  table_name = "sessions"
  hash_key = "session_id"
  app_name = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
```

Remove the table:
```bash
terraform plan    # Review: will DESTROY transactions table + IAM policy
                 # ⚠️ Warning: All data in table will be deleted!

terraform apply   # Type 'yes' to confirm deletion
```

**What happens:**
- Table `superblocksdemo-transactions` is **deleted** (data lost!)
- IAM policy `superblocksdemo-transactions-XXXXX` is **removed**
- Other tables remain unchanged

---

## 📋 Complete Workflow Example

```bash
# 1. Create first table
cat > main.tf <<'EOF'
module "users_table" {
  source             = "./modules/dynamodb"
  table_name         = "users"
  hash_key           = "user_id"
  range_key          = "created_at"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
EOF

terraform init
terraform apply

# 2. Add second table (append to main.tf)
cat >> main.tf <<'EOF'

module "transactions_table" {
  source             = "./modules/dynamodb"
  table_name         = "transactions"
  hash_key           = "txn_id"
  range_key          = "timestamp"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
EOF

terraform plan    # Shows: Plan: 2 to add (1 table + 1 policy)
terraform apply

# 3. List all tables
aws dynamodb list-tables --query 'TableNames[?starts_with(@, `superblocksdemo-`)]'

# 4. Remove a table (edit main.tf and delete the module block)
# Then run:
terraform plan    # Shows: Plan: 2 to destroy (1 table + 1 policy)
terraform apply
```

---

## 🔧 Configuration Details

| Setting | Value |
|---------|-------|
| **Billing Mode** | `PAY_PER_REQUEST` (on-demand) |
| **Encryption** | AWS managed key |
| **Backup** | Disabled (no point-in-time recovery) |
| **Deletion Protection** | Disabled |
| **Tags** | `Application: superblocksdemo` |

---

## 📝 Required Variables

| Variable | Type | Example | Notes |
|----------|------|---------|-------|
| `table_name` | string | `"users"` | Table name (will be prefixed with app_name) |
| `hash_key` | string | `"user_id"` | Partition key attribute name |
| `range_key` | string | `"created_at"` | Sort key (optional, leave empty if not needed) |
| `app_name` | string | `"superblocksdemo"` | Application name for tagging |
| `ecs_task_role_name` | string | `"superblocks-ecs-task"` | **NAME** not ARN ⚠️ |

### ⚠️ Important: Use Role NAME, Not ARN

The module expects the **role name**, not the full ARN:

```hcl
# ✅ CORRECT
ecs_task_role_name = "superblocks-ecs-task"

# ❌ WRONG
ecs_task_role_name = "arn:aws:iam::123456789012:role/superblocks-ecs-task"
```

**Why?** The Terraform `aws_iam_role_policy_attachment` resource expects a role name, not an ARN.

**How to find your role name:**
```bash
# If you have the ARN:
ARN="arn:aws:iam::123456789012:role/superblocks-ecs-task"
echo ${ARN##*/}  # Outputs: superblocks-ecs-task

# Or list all roles:
aws iam list-roles --query 'Roles[?contains(RoleName, `superblocks`)].RoleName'
```

---

## 📤 Outputs

```hcl
# Access table name and ARN
output "users_table_name" {
  value = module.users_table.table_name
  # Result: "superblocksdemo-users"
}

output "users_table_arn" {
  value = module.users_table.table_arn
  # Result: "arn:aws:dynamodb:us-east-1:123456789012:table/superblocksdemo-users"
}
```

---

## 🧪 Testing Your Tables

### AWS CLI
```bash
# Put item
aws dynamodb put-item \
  --table-name superblocksdemo-users \
  --item '{"user_id": {"S": "user123"}, "created_at": {"N": "1234567890"}}'

# Get item
aws dynamodb get-item \
  --table-name superblocksdemo-users \
  --key '{"user_id": {"S": "user123"}, "created_at": {"N": "1234567890"}}'

# List all your tables
aws dynamodb list-tables --query 'TableNames[?starts_with(@, `superblocksdemo-`)]'
```

### From ECS Application (Node.js)
```javascript
const { DynamoDBClient, PutItemCommand } = require("@aws-sdk/client-dynamodb");
const client = new DynamoDBClient({ region: "us-east-1" });

await client.send(new PutItemCommand({
  TableName: "superblocksdemo-users",
  Item: {
    user_id: { S: "user123" },
    created_at: { N: "1234567890" },
    name: { S: "John Doe" }
  }
}));
```

---

## 🎯 Common Patterns

### Single partition key (no sort key)
```hcl
module "sessions_table" {
  source             = "./modules/dynamodb"
  table_name         = "sessions"
  hash_key           = "session_id"
  # range_key omitted
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
```

### Number keys
```hcl
module "products_table" {
  source             = "./modules/dynamodb"
  table_name         = "products"
  hash_key           = "product_id"
  hash_key_type      = "N"  # Number instead of String
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
```

### Composite key (partition + sort)
```hcl
module "orders_table" {
  source             = "./modules/dynamodb"
  table_name         = "orders"
  hash_key           = "customer_id"  # Partition key
  range_key          = "order_date"   # Sort key
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
```

### Grant access to multiple roles (ECS + Bastion)
```hcl
module "users_table" {
  source             = "./modules/dynamodb"
  table_name         = "users"
  hash_key           = "user_id"
  range_key          = "created_at"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"

  # 🔑 Grant bastion host access for debugging/administration
  additional_role_names = [
    "superblocks-dev-bastion-role"
  ]
}
```

**Use case:** Access DynamoDB from bastion host for administration:
```bash
# Connect to bastion via SSM
aws ssm start-session --target i-1234567890abcdef0

# Query DynamoDB from bastion
aws dynamodb scan --table-name superblocksdemo-users --limit 10

# Get specific item
aws dynamodb get-item \
  --table-name superblocksdemo-users \
  --key '{"user_id": {"S": "user123"}, "created_at": {"N": "1234567890"}}'
```

---

## 💰 Cost Estimation

**Pay-per-request pricing:**
- Write: $1.25 per million requests
- Read: $0.25 per million requests
- Storage: $0.25 per GB-month

**Example per table:**
- 1M writes + 5M reads = $2.50
- 10GB storage = $2.50
- **Total: ~$5/month per table**

---

## 🔐 IAM Permissions

Each table automatically gets full CRUD permissions for the ECS task role:
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:UpdateItem`
- `dynamodb:DeleteItem`
- `dynamodb:Query`
- `dynamodb:Scan`
- `dynamodb:BatchGetItem`
- `dynamodb:BatchWriteItem`

---

## 🔐 Granting Access to SSO Users and Vendor Users

The module handles **per-table access** (ECS, bastion). For **global access** to ALL tables:

### SSO Users (Administrators/Developers)

**File**: `../../dynamodb-sso-access.tf`

```bash
# 1. Find your SSO roles
aws iam list-roles --query 'Roles[?contains(RoleName, `AWSReservedSSO`)].RoleName' --output text

# 2. Edit the file and add role names
vi ../../dynamodb-sso-access.tf

# Add to sso_roles_with_dynamodb_access:
#   "AWSReservedSSO_AWSAdministratorAccess_abc123def456",
#   "AWSReservedSSO_DeveloperAccess_xyz789ghi012",

# 3. Apply
terraform plan
terraform apply
```

**Note**: SSO role names don't change - they're permanent within your account.

### Vendor IAM Users (API Access with Access Keys)

**File**: `../../dynamodb-sso-access.tf`

```bash
# 1. Find IAM users with access keys
aws iam list-users --query 'Users[].UserName' --output table

# 2. Edit the file and add user names
vi ../../dynamodb-sso-access.tf

# Add to vendor_users_with_dynamodb_access:
#   "vendor-api-user",
#   "external-service",

# 3. Apply
terraform plan
terraform apply
```

This grants access to **all** `superblocksdemo-*` tables with a single policy.

---

## 📖 More Info

- **README.md** - Complete documentation with SSO/vendor access details
- **examples.tf** - More examples
- **../../dynamodb-sso-access.tf** - SSO and vendor user access configuration
