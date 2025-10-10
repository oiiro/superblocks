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
  ecs_task_role_name = "superblocks-ecs-task-role"  # NAME not ARN
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
  ecs_task_role_name = "superblocks-ecs-task-role"
}

module "transactions_table" {
  source             = "./modules/dynamodb"
  table_name         = "transactions"
  hash_key           = "txn_id"
  range_key          = "timestamp"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task-role"
}

module "sessions_table" {
  source             = "./modules/dynamodb"
  table_name         = "sessions"
  hash_key           = "session_id"
  app_name           = "superblocksdemo"
  ecs_task_role_name = "superblocks-ecs-task-role"
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
| `ecs_task_role_name` | ECS task IAM role **name** (not ARN) | `"superblocks-ecs-task-role"` |

**⚠️ Important**: Use the **role NAME**, not the ARN:
- ✅ Correct: `ecs_task_role_name = "superblocks-ecs-task-role"`
- ❌ Wrong: `ecs_task_role_name = "arn:aws:iam::123456789012:role/superblocks-ecs-task-role"`

### Optional

| Name | Description | Default |
|------|-------------|---------|
| `range_key` | Sort key attribute name | `""` (none) |
| `hash_key_type` | Hash key type (S/N/B) | `"S"` (String) |
| `range_key_type` | Range key type (S/N/B) | `"S"` (String) |

## Outputs

| Name | Description |
|------|-------------|
| `table_name` | Full name of the DynamoDB table (e.g., `superblocksdemo-users`) |
| `table_arn` | ARN of the DynamoDB table |

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
  ecs_task_role_name = "superblocks-ecs-task-role"
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
  ecs_task_role_name = "superblocks-ecs-task-role"
}
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
aws iam list-attached-role-policies --role-name superblocks-ecs-task-role

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
ARN="arn:aws:iam::123456789012:role/superblocks-ecs-task-role"
echo ${ARN##*/}  # Outputs: superblocks-ecs-task-role
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

## Files

- **[QUICKSTART.md](./QUICKSTART.md)** - Step-by-step workflow guide
- **[examples.tf](./examples.tf)** - More usage examples
- **main.tf** - Module implementation
- **variables.tf** - Input variables
- **outputs.tf** - Output values

## License

This module is provided as-is for use with Superblocks infrastructure.
