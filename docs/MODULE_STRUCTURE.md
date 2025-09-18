# Superblocks Module Structure

## Overview

All implementations now use a consistent module structure based on the reusable `superblocks_agent` module. This makes it easy to compare configurations and understand the differences between implementations.

## Module Architecture

```
terraform/
├── modules/
│   └── superblocks_agent/          # Reusable module
│       ├── main.tf                 # Core infrastructure
│       ├── variables.tf            # Input parameters
│       └── outputs.tf              # Return values
├── superblocks-simple/             # HTTP implementation
│   ├── main.tf                     # Calls module with enable_ssl = false
│   ├── variables.tf                # Pass-through variables
│   └── outputs.tf                  # Module outputs
├── superblocks-simple-https/       # HTTPS implementation
│   ├── main.tf                     # Calls module with enable_ssl = true
│   ├── variables.tf                # Pass-through variables
│   └── outputs.tf                  # Module outputs
└── superblocks/                    # Official module (buggy)
    ├── main.tf                     # Uses official module
    └── ...
```

## Key Implementation Differences

The main difference between implementations is a single parameter:

### HTTP Implementation (superblocks-simple)
```hcl
module "superblocks_agent" {
  source = "../modules/superblocks_agent"
  
  # SSL Configuration - DISABLED for HTTP-only
  enable_ssl      = false
  certificate_arn = ""
  
  # All other parameters identical...
}
```

### HTTPS Implementation (superblocks-simple-https)
```hcl
module "superblocks_agent" {
  source = "../modules/superblocks_agent"
  
  # SSL Configuration - ENABLED with self-signed certificate
  enable_ssl      = true
  certificate_arn = var.certificate_arn  # Empty = auto-generate
  ssl_policy      = var.ssl_policy
  
  # All other parameters identical...
}
```

## Module Features

The `superblocks_agent` module provides:

### Core Infrastructure
- ECS Cluster with Fargate
- Application Load Balancer
- Target Groups (HTTP and gRPC)
- Security Groups
- IAM Roles
- CloudWatch Log Groups

### Conditional SSL Support
- **When `enable_ssl = false`**: HTTP-only ALB listener
- **When `enable_ssl = true`**: HTTPS listener + HTTP redirect

### Auto-Generated Certificates
- **When `enable_ssl = true` and `certificate_arn = ""`**: Creates self-signed certificate
- **When `enable_ssl = true` and `certificate_arn = "arn:..."`**: Uses provided certificate

### Auto Scaling (Optional)
- Configurable CPU-based auto scaling
- Target tracking scaling policies

## Benefits of Module Structure

### 1. Consistency
All implementations use the same underlying infrastructure code.

### 2. Easy Comparison
The only differences are in the module parameters, making it easy to see what changes between HTTP and HTTPS.

### 3. Maintainability
Bug fixes and improvements only need to be made in one place (the module).

### 4. Reusability
The module can be used in other projects with different configurations.

### 5. Testing
Each implementation can be tested independently while sharing the same core logic.

## Configuration Comparison

| Parameter | HTTP Version | HTTPS Version | Description |
|-----------|-------------|---------------|-------------|
| `enable_ssl` | `false` | `true` | Enable/disable SSL |
| `certificate_arn` | `""` | `""` or `"arn:..."` | Certificate to use |
| `ssl_policy` | Not used | `"ELBSecurityPolicy-..."` | SSL policy |
| **All others** | **Identical** | **Identical** | Same configuration |

## Usage Examples

### Deploy HTTP Version
```bash
cd terraform/superblocks-simple
terraform init
terraform apply -var-file="../environments/superblocks.tfvars"
```

### Deploy HTTPS Version
```bash
cd terraform/superblocks-simple-https
terraform init
terraform apply -var-file="../environments/superblocks.tfvars"
```

### Switch Between Versions
```bash
# Destroy old version
terraform destroy -var-file="../environments/superblocks.tfvars"

# Deploy new version
cd ../superblocks-simple-https
terraform apply -var-file="../environments/superblocks.tfvars"
```

## Module Parameters

The module accepts these key parameters:

```hcl
module "superblocks_agent" {
  # Basic Configuration
  name_prefix = "superblocks"
  aws_region  = "us-east-1"

  # Network (from VPC remote state)
  vpc_id         = data.terraform_remote_state.vpc.outputs.vpc_id
  lb_subnet_ids  = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  ecs_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  # Superblocks Agent
  superblocks_agent_key = "sb_agent_xxxxx"

  # SSL (main difference)
  enable_ssl = true/false

  # Resource Sizing
  cpu_units    = 1024
  memory_units = 2048
  
  # Auto Scaling
  enable_auto_scaling = true
  min_capacity       = 1
  max_capacity       = 3
}
```

## Summary

The modular structure provides:
- **Clear separation** between HTTP and HTTPS configurations
- **Easy migration** between implementations
- **Consistent infrastructure** across all deployments
- **Single source of truth** for Superblocks deployment logic

This approach follows Infrastructure as Code best practices and makes the codebase much more maintainable.