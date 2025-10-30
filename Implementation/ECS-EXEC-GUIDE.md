# ECS Exec Guide - Debugging Kong Containers

ECS Exec allows you to execute commands inside running ECS containers, similar to `docker exec`. This is useful for debugging, inspecting logs, and troubleshooting.

## Prerequisites

### 1. Enable ECS Exec on Services (Already Configured)

When creating services, the `--enable-execute-command` flag is included in DEPLOYMENT.md:

```bash
aws ecs create-service \
  --enable-execute-command \
  ...
```

### 2. Update Task Role IAM Permissions

Attach the policy to `kong-gw-TaskRole`:

```bash
# Create the policy
aws iam create-policy \
  --policy-name KongECSExecPolicy \
  --policy-document file://iam-task-role-policy.json

# Attach to task role
aws iam attach-role-policy \
  --role-name kong-gw-TaskRole \
  --policy-arn arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:policy/KongECSExecPolicy
```

### 3. Install Session Manager Plugin (One-time)

On your local machine:

**macOS:**
```bash
# Using Homebrew
brew install --cask session-manager-plugin

# Or download from AWS
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
unzip sessionmanager-bundle.zip
sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
```

**Linux:**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo yum install -y session-manager-plugin.rpm
```

**Windows:**
```powershell
# Download and install from:
# https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe
```

## Using ECS Exec

### Access Control Plane Container

```bash
# List running tasks
aws ecs list-tasks \
  --cluster kong-gateway-cluster \
  --service-name kong-control-plane \
  --region ap-southeast-1

# Get task ID from output (e.g., arn:aws:ecs:ap-southeast-1:123456789012:task/kong-gateway-cluster/abc123...)

# Execute command in container
aws ecs execute-command \
  --cluster kong-gateway-cluster \
  --task <TASK_ID> \
  --container kong-control \
  --interactive \
  --command "/bin/sh" \
  --region ap-southeast-1
```

### Access Data Plane Container

```bash
# List data plane tasks
aws ecs list-tasks \
  --cluster kong-gateway-cluster \
  --service-name kong-data-plane \
  --region ap-southeast-1

# Execute command
aws ecs execute-command \
  --cluster kong-gateway-cluster \
  --task <TASK_ID> \
  --container kong-data \
  --interactive \
  --command "/bin/sh" \
  --region ap-southeast-1
```

## Common Debugging Commands

Once inside the container:

### Check Kong Configuration

```bash
# View Kong configuration
kong config db_export /tmp/kong-config.yml
cat /tmp/kong-config.yml

# Check Kong version
kong version

# View environment variables
env | grep KONG_
```

### Check Database Connectivity

```bash
# Test PostgreSQL connection (Control Plane only)
psql -h $KONG_PG_HOST -U $KONG_PG_USER -d $KONG_PG_DATABASE -c "SELECT version();"

# Check database tables
psql -h $KONG_PG_HOST -U $KONG_PG_USER -d $KONG_PG_DATABASE -c "\dt"
```

### Check Cluster Connectivity

```bash
# From Data Plane: Test connection to Control Plane
nc -zv config.kong.local 8005

# From Data Plane: Check DNS resolution
nslookup config.kong.local

# Check certificates
openssl x509 -in /etc/kong/certs/cluster.crt -text -noout
```

### Check Kong Logs

```bash
# View error logs
tail -f /usr/local/kong/logs/error.log

# View access logs
tail -f /usr/local/kong/logs/access.log

# Check Kong status
curl -i http://localhost:8001/status  # Control Plane
curl -i http://localhost:8000/status  # Data Plane
```

### Network Debugging

```bash
# Check listening ports
netstat -tlnp

# Test DNS resolution
nslookup config.kong.local

# Test connectivity
curl http://localhost:8001  # Control Plane Admin API
curl http://localhost:8000  # Data Plane Proxy
```

### File System Inspection

```bash
# Check Kong installation
ls -la /usr/local/kong/

# View Kong configuration file
cat /etc/kong/kong.conf

# Check certificates
ls -la /etc/kong/certs/
```

## Helper Script

Create a quick access script:

```bash
#!/bin/bash
# exec-kong.sh

SERVICE_NAME=$1  # kong-control-plane or kong-data-plane
CLUSTER_NAME="kong-gateway-cluster"
REGION="ap-southeast-1"

if [ "$SERVICE_NAME" == "kong-control-plane" ]; then
    CONTAINER="kong-control"
elif [ "$SERVICE_NAME" == "kong-data-plane" ]; then
    CONTAINER="kong-data"
else
    echo "Usage: $0 [kong-control-plane|kong-data-plane]"
    exit 1
fi

# Get first running task
TASK_ID=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --region $REGION \
    --query 'taskArns[0]' \
    --output text)

echo "Connecting to $SERVICE_NAME..."
echo "Task: $TASK_ID"
echo "Container: $CONTAINER"

aws ecs execute-command \
    --cluster $CLUSTER_NAME \
    --task $TASK_ID \
    --container $CONTAINER \
    --interactive \
    --command "/bin/sh" \
    --region $REGION
```

Usage:
```bash
chmod +x exec-kong.sh
./exec-kong.sh kong-control-plane
./exec-kong.sh kong-data-plane
```

## Troubleshooting ECS Exec

### "ExecuteCommandAgent is not running"

The task needs to be restarted after enabling execute command:

```bash
# Force new deployment
aws ecs update-service \
  --cluster kong-gateway-cluster \
  --service kong-control-plane \
  --force-new-deployment \
  --enable-execute-command \
  --region ap-southeast-1
```

### "Session Manager plugin not found"

Install the Session Manager plugin (see Prerequisites above).

### "AccessDeniedException"

Check that:
1. Task role has SSM permissions (iam-task-role-policy.json)
2. Your IAM user/role has `ecs:ExecuteCommand` permission

Add to your IAM user/role:
```json
{
  "Effect": "Allow",
  "Action": [
    "ecs:ExecuteCommand",
    "ecs:DescribeTasks"
  ],
  "Resource": "*"
}
```

### Check if ECS Exec is Enabled

```bash
# Describe service
aws ecs describe-services \
  --cluster kong-gateway-cluster \
  --services kong-control-plane \
  --query 'services[0].enableExecuteCommand' \
  --region ap-southeast-1

# Should return: true
```

## Security Considerations

1. **Audit Logging**: All ECS Exec sessions are logged to CloudWatch Logs at `/aws/ecs/execute-command/<cluster>/<task-id>`

2. **IAM Permissions**: Restrict who can execute commands:
   ```json
   {
     "Effect": "Allow",
     "Action": "ecs:ExecuteCommand",
     "Resource": "arn:aws:ecs:*:*:task/kong-gateway-cluster/*",
     "Condition": {
       "StringEquals": {
         "aws:RequestedRegion": "ap-southeast-1"
       }
     }
   }
   ```

3. **Read-Only Access**: Use `--command "cat /etc/kong/kong.conf"` for read-only operations

4. **Disable in Production**: Consider disabling ECS Exec in production and only enabling when needed:
   ```bash
   aws ecs update-service \
     --cluster kong-gateway-cluster \
     --service kong-control-plane \
     --no-enable-execute-command
   ```

## References

- [AWS ECS Exec Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html)
- [Session Manager Plugin Installation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- [Kong Configuration Reference](https://docs.konghq.com/gateway/latest/reference/configuration/)

---

**Quick Reference**:
```bash
# Access Control Plane
aws ecs execute-command --cluster kong-gateway-cluster --task <TASK_ID> --container kong-control --interactive --command "/bin/sh"

# Access Data Plane
aws ecs execute-command --cluster kong-gateway-cluster --task <TASK_ID> --container kong-data --interactive --command "/bin/sh"

# Check Kong status
curl http://localhost:8001/status
```
