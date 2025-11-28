# K3s Automatic Worker Node Joining

## Overview

The K3s setup now includes **automatic worker node joining** using AWS services. Worker nodes will automatically discover the K3s server and join the cluster without manual configuration.

## How It Works

### Server Side (`k3s_server.sh`)

1. **Installs K3s server**
2. **Stores join token in AWS SSM Parameter Store**
   - Parameter name: `/k3s/server/token`
   - Type: SecureString (encrypted)
   - Region: Auto-detected from EC2 metadata

3. **Tags itself** (via Terraform)
   - Tag: `Role=k3s-server`
   - Used by agents to discover server IP

### Agent Side (`k3s_agent.sh`)

1. **Discovers K3s server IP**
   - Queries EC2 API for instances with tag `Role=k3s-server`
   - Uses private IP for internal communication

2. **Retrieves join token**
   - Fetches from SSM Parameter Store: `/k3s/server/token`
   - Waits up to 5 minutes for token to be available

3. **Joins cluster automatically**
   - No manual configuration needed
   - Retries if server not ready yet

## Required IAM Permissions

### K3s Server Instance Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:GetParameter"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/k3s/server/token"
    }
  ]
}
```

### K3s Agent Instance Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/k3s/server/token"
    }
  ]
}
```

## Terraform Configuration

### Add IAM Roles

```hcl
# IAM role for K3s server
resource "aws_iam_role" "k3s_server_role" {
  name = "k3s-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "k3s_server_policy" {
  name = "k3s-server-policy"
  role = aws_iam_role.k3s_server_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:PutParameter",
        "ssm:GetParameter"
      ]
      Resource = "arn:aws:ssm:*:*:parameter/k3s/server/token"
    }]
  })
}

resource "aws_iam_instance_profile" "k3s_server_profile" {
  name = "k3s-server-profile"
  role = aws_iam_role.k3s_server_role.name
}

# IAM role for K3s agents
resource "aws_iam_role" "k3s_agent_role" {
  name = "k3s-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "k3s_agent_policy" {
  name = "k3s-agent-policy"
  role = aws_iam_role.k3s_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter/k3s/server/token"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k3s_agent_profile" {
  name = "k3s-agent-profile"
  role = aws_iam_role.k3s_agent_role.name
}
```

### Update EC2 Instances

```hcl
# K3s Server
module "k3s_master_instance" {
  source = "../MODULES/EC2"
  # ... other configuration ...
  
  iam_instance_profile = aws_iam_instance_profile.k3s_server_profile.name
  
  tags = {
    Name = "K3s-Server"
    Role = "k3s-server"  # Required for agent discovery
  }
}

# K3s Worker
module "K3s_worker_instance" {
  source = "../MODULES/EC2"
  # ... other configuration ...
  
  iam_instance_profile = aws_iam_instance_profile.k3s_agent_profile.name
  
  tags = {
    Name = "K3s-Worker"
    Role = "k3s-agent"
  }
}
```

## Manual Join (Fallback)

If automatic joining fails, you can still join manually:

```bash
# On K3s server, get the token
cat ~/k3s-token.txt

# On worker node
export K3S_SERVER_IP="<server-private-ip>"
export K3S_TOKEN="<token-from-above>"

curl -sfL https://get.k3s.io | K3S_URL=https://${K3S_SERVER_IP}:6443 \
    K3S_TOKEN=${K3S_TOKEN} sh -s - agent
```

## Verification

### On K3s Server

```bash
# Check if token is in SSM
aws ssm get-parameter --name /k3s/server/token --with-decryption

# Check nodes
kubectl get nodes
```

### On K3s Agent

```bash
# Check agent logs
sudo journalctl -u k3s-agent -f

# Check if agent is running
sudo systemctl status k3s-agent
```

## Troubleshooting

### Agent can't find server IP

**Problem**: `ERROR: Could not find K3s server IP from EC2 tags`

**Solution**: Ensure the K3s server instance has the tag `Role=k3s-server`

```bash
# Check server tags
aws ec2 describe-instances --instance-ids <server-instance-id> --query 'Reservations[0].Instances[0].Tags'
```

### Agent can't retrieve token

**Problem**: `ERROR: Could not retrieve K3s token from SSM Parameter Store`

**Solutions**:
1. Check IAM permissions for agent instance role
2. Verify token exists in SSM:
   ```bash
   aws ssm get-parameter --name /k3s/server/token
   ```
3. Check if server finished installation

### Server can't store token in SSM

**Problem**: `⚠ Could not store token in SSM`

**Solutions**:
1. Check IAM permissions for server instance role
2. Verify AWS CLI is installed: `aws --version`
3. Check region is correct

## Benefits

✅ **Zero manual configuration** - Workers join automatically
✅ **Secure** - Token stored encrypted in SSM
✅ **Resilient** - Automatic retries if server not ready
✅ **Scalable** - Add workers anytime, they'll auto-join
✅ **Simple** - Just launch instances with correct IAM roles

## Next Steps

1. **Update Terraform** - Add IAM roles and instance profiles
2. **Apply changes** - `terraform apply`
3. **Launch instances** - Workers will auto-join
4. **Verify** - `kubectl get nodes` on server
