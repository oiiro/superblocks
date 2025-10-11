# DynamoDB Table Module for Superblocks

Simple, modular Terraform module for creating DynamoDB tables accessible by ECS tasks.

## 🚀 Quick Start

**New to this module?** Start here: **[QUICKSTART.md](./QUICKSTART.md)**

The Quick Start guide shows you how to:
- Create your first table
- Add more tables incrementally
- Remove tables safely
- Complete step-by-step workflow with commands

## Features

- ✅ **Pay-per-request billing** - No capacity planning required
- ✅ **AWS managed encryption** - Automatic encryption at rest
- ✅ **ECS IAM access** - Automatic policy attachment to ECS task role
- ✅ **Modular design** - Easy to add multiple tables
- ✅ **Simple configuration** - Only 4 required variables

## Configuration

| Setting | Value |
|---------|-------|
| Billing Mode | PAY_PER_REQUEST (on-demand) |
| Encryption | AWS managed key |
| Backup | Disabled (no point-in-time recovery) |
| Deletion Protection | Disabled |
| Tags | `Application: superblocksdemo` |

## Basic Usage

```hcl
module "users_table" {
  source = "./modules/dynamodb"

  table_name         = "users"
  hash_key           = "user_id"
  range_key          = "created_at"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"  # NAME not ARN
}
```

### Multiple Tables

```hcl
module "users_table" {
  source             = "./modules/dynamodb"
  table_name         = "users"
  hash_key           = "user_id"
  range_key          = "created_at"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}

module "transactions_table" {
  source             = "./modules/dynamodb"
  table_name         = "transactions"
  hash_key           = "txn_id"
  range_key          = "timestamp"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}

module "sessions_table" {
  source             = "./modules/dynamodb"
  table_name         = "sessions"
  hash_key           = "session_id"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
```

**See [examples.tf](./examples.tf) for more patterns.**

## Variables

### Required

| Name | Description | Example |
|------|-------------|---------|
| `table_name` | Name of the DynamoDB table | `"users"` |
| `hash_key` | Partition key attribute name | `"user_id"` |
| `app_name` | Application name for tagging | `"superblocksdemo"` |
| `ecs_task_role_name` | ECS task IAM role **name** (not ARN) | `"superblocks-ecs-task"` |

**⚠️ Important**: Use the **role NAME**, not the ARN:
- ✅ Correct: `ecs_task_role_name = "superblocks-ecs-task"`
- ❌ Wrong: `ecs_task_role_name = "arn:aws:iam::123456789012:role/superblocks-ecs-task"`

### Optional

| Name | Description | Default |
|------|-------------|---------|
| `range_key` | Sort key attribute name | `""` (none) |
| `hash_key_type` | Hash key type (S/N/B) | `"S"` (String) |
| `range_key_type` | Range key type (S/N/B) | `"S"` (String) |
| `additional_role_names` | Additional IAM roles needing access (e.g., bastion) | `[]` (none) |

## Outputs

| Name | Description |
|------|-------------|
| `table_name` | Full name of the DynamoDB table (e.g., `superblocksdemo-users`) |
| `table_arn` | ARN of the DynamoDB table |
| `iam_policy_arn` | ARN of the IAM policy granting access |
| `attached_roles` | List of all IAM roles with access to the table |

## Table Naming

Tables are automatically prefixed with the app name:
- Input: `table_name = "users"`, `app_name = "superblocksdemo"`
- Result: `superblocksdemo-users`

## IAM Permissions

Each table automatically gets an IAM policy attached to the ECS task role with full CRUD access:

- `dynamodb:BatchGetItem` / `BatchWriteItem`
- `dynamodb:GetItem` / `PutItem` / `UpdateItem` / `DeleteItem`
- `dynamodb:Query` / `Scan`
- `dynamodb:DescribeTable`

## Using from Your Application

### Node.js

```javascript
const { DynamoDBClient, PutItemCommand, GetItemCommand } = require("@aws-sdk/client-dynamodb");

const client = new DynamoDBClient({ region: "us-east-1" });

// Put item
await client.send(new PutItemCommand({
  TableName: "superblocksdemo-users",
  Item: {
    user_id: { S: "user123" },
    created_at: { N: "1234567890" },
    name: { S: "John Doe" }
  }
}));

// Get item
const response = await client.send(new GetItemCommand({
  TableName: "superblocksdemo-users",
  Key: {
    user_id: { S: "user123" },
    created_at: { N: "1234567890" }
  }
}));
```

### Python

```python
import boto3

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('superblocksdemo-users')

# Put item
table.put_item(Item={
    'user_id': 'user123',
    'created_at': 1234567890,
    'name': 'John Doe'
})

# Get item
response = table.get_item(Key={
    'user_id': 'user123',
    'created_at': 1234567890
})
item = response['Item']
```

### Java

```java
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;

DynamoDbClient client = DynamoDbClient.builder()
    .region(Region.US_EAST_1)
    .build();

// Put item
client.putItem(PutItemRequest.builder()
    .tableName("superblocksdemo-users")
    .item(Map.of(
        "user_id", AttributeValue.builder().s("user123").build(),
        "created_at", AttributeValue.builder().n("1234567890").build(),
        "name", AttributeValue.builder().s("John Doe").build()
    ))
    .build());
```

## AWS CLI

```bash
# Put item
aws dynamodb put-item \
  --table-name superblocksdemo-users \
  --item '{"user_id": {"S": "user123"}, "created_at": {"N": "1234567890"}}'

# Get item
aws dynamodb get-item \
  --table-name superblocksdemo-users \
  --key '{"user_id": {"S": "user123"}, "created_at": {"N": "1234567890"}}'

# Query by partition key
aws dynamodb query \
  --table-name superblocksdemo-users \
  --key-condition-expression "user_id = :uid" \
  --expression-attribute-values '{":uid": {"S": "user123"}}'

# List all your tables
aws dynamodb list-tables --query 'TableNames[?starts_with(@, `superblocksdemo-`)]'
```

## Common Patterns

### Table without range key
```hcl
module "sessions_table" {
  source             = "./modules/dynamodb"
  table_name         = "sessions"
  hash_key           = "session_id"
  # No range_key
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
```

### Table with number keys
```hcl
module "products_table" {
  source             = "./modules/dynamodb"
  table_name         = "products"
  hash_key           = "product_id"
  hash_key_type      = "N"  # Number instead of String
  range_key          = "category"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"
}
```

### Grant Access to Multiple Roles (ECS + Bastion)
```hcl
module "users_table" {
  source             = "./modules/dynamodb"
  table_name         = "users"
  hash_key           = "user_id"
  range_key          = "created_at"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task"

  # Grant bastion host access for administration
  additional_role_names = [
    "superblocks-dev-bastion-role"
  ]
}
```

**Use case:** Allow bastion EC2 instance to access DynamoDB for debugging/administration:
```bash
# From bastion host
aws dynamodb scan --table-name superblocksdemo-users --limit 10
aws dynamodb get-item --table-name superblocksdemo-users \
  --key '{"user_id": {"S": "user123"}}'
```

## Key Types

| Type | Description | Example Value |
|------|-------------|---------------|
| `S` | String | `"user123"` |
| `N` | Number | `1234567890` |
| `B` | Binary | Binary data |

## Cost Estimation

**Pay-per-request pricing (on-demand):**
- Write: $1.25 per million requests
- Read: $0.25 per million requests
- Storage: $0.25 per GB-month

**Example monthly cost per table:**
- 1M writes + 5M reads = $2.50
- 10GB storage = $2.50
- **Total: ~$5/month**

## Monitoring

Monitor your tables in CloudWatch:
- `ConsumedReadCapacityUnits` - Read usage
- `ConsumedWriteCapacityUnits` - Write usage
- `UserErrors` - Client errors
- `SystemErrors` - Server errors

## Deployment

```bash
# Initialize Terraform
terraform init

# Review changes
terraform plan

# Apply changes
terraform apply

# Verify tables
aws dynamodb list-tables --query 'TableNames[?starts_with(@, `superblocksdemo-`)]'
```

## Troubleshooting

### Access Denied

```bash
# Verify IAM policy is attached
aws iam list-attached-role-policies --role-name superblocks-ecs-task

# Check policies
aws iam list-policies --scope Local | grep superblocksdemo
```

### Table Not Found

```bash
# List all tables
aws dynamodb list-tables

# Check specific table
aws dynamodb describe-table --table-name superblocksdemo-users
```

### Role Name vs ARN Error

If you see errors about the role not being found, verify you're using the **role name**, not the ARN:

```bash
# Extract name from ARN
ARN="arn:aws:iam::123456789012:role/superblocks-ecs-task"
echo ${ARN##*/}  # Outputs: superblocks-ecs-task
```

## Architecture

```
┌─────────────────────────────────────┐
│       ECS Cluster (Fargate)         │
│   ┌─────────────────────────────┐   │
│   │  ECS Task                   │   │
│   │  Role: superblocks-ecs-task │   │
│   │  • IAM Policy attached      │   │
│   └──────────┬──────────────────┘   │
└──────────────┼──────────────────────┘
               │ Full CRUD Access
               ▼
┌─────────────────────────────────────┐
│        DynamoDB Tables              │
├─────────────────────────────────────┤
│  • superblocksdemo-users            │
│  • superblocksdemo-transactions     │
│  • superblocksdemo-sessions         │
│                                     │
│  Settings:                          │
│  • Pay-per-request billing          │
│  • AWS managed encryption           │
│  • No backup                        │
│  • Tagged: superblocksdemo          │
└─────────────────────────────────────┘
```

## Granting Access to SSO Users and Vendor Users

The module handles per-table access (ECS tasks, bastion hosts). For **global access** to all DynamoDB tables by SSO users or vendor IAM users, use the separate configuration file outside the module.

### SSO Users (AWS IAM Identity Center)

Grant access to users who log in via SSO:

**File**: `dynamodb-sso-access.tf` (in root terraform directory)

```hcl
locals {
  sso_roles_with_dynamodb_access = [
    "AWSReservedSSO_AWSAdministratorAccess_abc123def456",
    "AWSReservedSSO_DeveloperAccess_xyz789ghi012",
  ]
}
```

**Find your SSO roles**:
```bash
# List all SSO roles
aws iam list-roles --query 'Roles[?contains(RoleName, `AWSReservedSSO`)].RoleName' --output table

# Get your current SSO role
aws sts get-caller-identity
```

**Important**: SSO role names are permanent and don't change per session. The suffix (e.g., `abc123def456`) is constant within your account.

### Vendor IAM Users (Access Key/Secret Key)

Grant access to external vendors/services that use IAM user credentials:

**File**: `dynamodb-sso-access.tf` (in root terraform directory)

```hcl
locals {
  vendor_users_with_dynamodb_access = [
    "vendor-api-user",
    "external-service",
  ]
}
```

**Find vendor IAM users**:
```bash
# List all IAM users
aws iam list-users --query 'Users[].UserName' --output table

# Check which users have access keys (API access)
aws iam list-users --query 'Users[].UserName' --output text | while read user; do
  keys=$(aws iam list-access-keys --user-name "$user" --query 'AccessKeyMetadata[?Status==`Active`].AccessKeyId' --output text)
  if [ -n "$keys" ]; then
    echo "User: $user | Keys: $keys"
  fi
done
```

### Deployment

```bash
# 1. Edit dynamodb-sso-access.tf with your SSO roles and vendor users
vi dynamodb-sso-access.tf

# 2. Plan and apply
terraform plan
terraform apply
```

This creates a single IAM policy that grants access to **all** `superblocksdemo-*` tables and attaches it to the specified SSO roles and vendor users.

**See**: `../../dynamodb-sso-access.tf` for the complete configuration

---

## Files

- **[QUICKSTART.md](./QUICKSTART.md)** - Step-by-step workflow guide
- **[examples.tf](./examples.tf)** - More usage examples
- **main.tf** - Module implementation
- **variables.tf** - Input variables
- **outputs.tf** - Output values
- **../../dynamodb-sso-access.tf** - SSO and vendor user access configuration

## License

This module is provided as-is for use with Superblocks infrastructure.
