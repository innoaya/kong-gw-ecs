# Kong Gateway Deployment on AWS ECS

## Prerequisites

Complete infrastructure setup from `INFRASTRUCTURE-SETUP.md` first.

Required:
- VPC with public and private subnets
- Security Groups configured
- IAM Roles created (both required)
- CloudWatch Log Groups created
- Aurora Serverless v2 PostgreSQL cluster
- ECS Cluster
- Service Discovery (Cloud Map)
- Application Load Balancer

### IAM Roles Required

Two IAM roles are required for ECS task execution:

**1. Task Execution Role** (`ecsTaskExecutionRole`):
- Used by ECS service to pull container images and write logs
- Attached policy: AWS managed `AmazonECSTaskExecutionRolePolicy`
- Permissions: ECR image pull, CloudWatch Logs write
- Required in task definition: `executionRoleArn`

**2. Task Role** (`kong-gw-TaskRole`):
- Used by the container application itself
- Custom inline policy: `KongECSExecPolicy` (from `iam-task-role-policy.json`)
- Permissions: SSM Session Manager (for ECS Exec), CloudWatch Logs
- Required in task definition: `taskRoleArn`

Both roles must be created before registering task definitions.

### Generate mTLS Certificates

```bash
./generate-shared-mtls-cert.sh
# Generates: cluster.crt, cluster.key
```

## Deployment Steps

### 1. Create ECS Cluster

```bash
aws ecs create-cluster \
  --cluster-name kong-gateway-cluster \
  --capacity-providers FARGATE \
  --region ap-southeast-1
```

### 2. Create Service Discovery

```bash
# Create namespace
aws servicediscovery create-private-dns-namespace \
  --name kong.local \
  --vpc vpc-xxxxxxxx \
  --region ap-southeast-1

# Create service
aws servicediscovery create-service \
  --name config \
  --namespace-id ns-xxxxxxxxx \
  --dns-config "NamespaceId=ns-xxxxxxxxx,DnsRecords=[{Type=A,TTL=10}]" \
  --health-check-custom-config FailureThreshold=1 \
  --region ap-southeast-1
```

### 3. Setup Aurora Serverless v2 PostgreSQL

```bash
# Create Aurora Serverless v2 cluster
aws rds create-db-cluster \
  --db-cluster-identifier kong-gw-uat \
  --engine aurora-postgresql \
  --engine-version 15.4 \
  --master-username kongadmin \
  --master-user-password <password> \
  --database-name kong \
  --vpc-security-group-ids sg-aurora \
  --db-subnet-group-name kong-db-subnet-group \
  --backup-retention-period 7 \
  --storage-encrypted \
  --engine-mode provisioned \
  --serverless-v2-scaling-configuration MinCapacity=0,MaxCapacity=2 \
  --region ap-southeast-1

# Create Serverless v2 instance
aws rds create-db-instance \
  --db-instance-identifier kong-gw-uat-instance-1 \
  --db-instance-class db.serverless \
  --engine aurora-postgresql \
  --db-cluster-identifier kong-gw-uat \
  --region ap-southeast-1

# Note: With MinCapacity=0, database scales to $0 when idle
# First connection after idle may take 15-30 seconds to resume

# Store credentials in Secrets Manager
aws secretsmanager create-secret \
  --name kong/database/credentials \
  --secret-string '{"username":"kongadmin","password":"<password>","host":"<endpoint>","port":"5432","dbname":"kong"}' \
  --region ap-southeast-1
```

### 4. Run Database Migrations (First Time Setup)

**Important**: Must be done before deploying control plane.

#### Option A: ECS Run-Task (Recommended)

Create migration task definition:

```json
{
  "family": "kong-migrations",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::802368621649:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "kong-migrations",
      "image": "kong:latest",
      "command": ["kong", "migrations", "bootstrap"],
      "environment": [
        {"name": "KONG_DATABASE", "value": "postgres"},
        {"name": "KONG_PG_HOST", "value": "kong-gw-uat-instance-1.cci5wy06ehkw.ap-southeast-1.rds.amazonaws.com"},
        {"name": "KONG_PG_PORT", "value": "5432"},
        {"name": "KONG_PG_DATABASE", "value": "kong"},
        {"name": "KONG_PG_USER", "value": "kongadmin"},
        {"name": "KONG_PG_PASSWORD", "value": "<password>"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/fargate/kong-migrations",
          "awslogs-region": "ap-southeast-1",
          "awslogs-stream-prefix": "migrations",
          "awslogs-create-group": "true"
        }
      }
    }
  ]
}
```

Run migration:

```bash
# Register task
aws ecs register-task-definition --cli-input-json file://kong-migrations-task.json

# Run migration
aws ecs run-task \
  --cluster kong-gateway-cluster \
  --task-definition kong-migrations \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-private-1],securityGroups=[sg-kong-cp],assignPublicIp=DISABLED}" \
  --region ap-southeast-1

# View logs
aws logs tail /fargate/kong-migrations --follow
```

Expected output: `Database is up-to-date`

#### Option B: From Bastion Host

```bash
docker run --rm \
  -e KONG_DATABASE=postgres \
  -e KONG_PG_HOST=<aurora-endpoint> \
  -e KONG_PG_PORT=5432 \
  -e KONG_PG_DATABASE=kong \
  -e KONG_PG_USER=kongadmin \
  -e KONG_PG_PASSWORD=<password> \
  kong:latest kong migrations bootstrap
```

#### Verify Migration

```bash
psql -h <aurora-endpoint> -U kongadmin -d kong -c "\dt"
# Should list Kong tables: acls, acme_storage, apis, etc.
```

### 5. Deploy Control Plane

```bash
# Register task definition
aws ecs register-task-definition --cli-input-json file://kong-cp-task-definition.json

# Create service with service discovery
aws ecs create-service \
  --cluster kong-gateway-cluster \
  --service-name kong-control-plane \
  --task-definition kong-control-plane:16 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-private-1,subnet-private-2],securityGroups=[sg-kong-cp],assignPublicIp=DISABLED}" \
  --service-registries "registryArn=arn:aws:servicediscovery:...:service/srv-xxxxx,containerName=kong-control,containerPort=8005" \
  --enable-execute-command \
  --region ap-southeast-1
```

Verify:
```bash
curl http://config.kong.local:8001/status
```

### 6. Deploy Data Plane

```bash
# Create ALB and target group
aws elbv2 create-target-group \
  --name kong-data-plane-tg \
  --protocol HTTP \
  --port 8000 \
  --vpc-id vpc-xxxxxxxx \
  --target-type ip \
  --health-check-path /status

aws elbv2 create-load-balancer \
  --name kong-data-plane-alb \
  --subnets subnet-public-1 subnet-public-2 \
  --security-groups sg-alb \
  --scheme internet-facing

aws elbv2 create-listener \
  --load-balancer-arn <alb-arn> \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=<tg-arn>

# Register task definition
aws ecs register-task-definition --cli-input-json file://kong-dp-task-definition.json

# Create service
aws ecs create-service \
  --cluster kong-gateway-cluster \
  --service-name kong-data-plane \
  --task-definition kong-data-plane:9 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-public-1,subnet-public-2],securityGroups=[sg-kong-dp],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=<tg-arn>,containerName=kong-data,containerPort=8000" \
  --region ap-southeast-1
```

Verify:
```bash
curl http://<alb-dns>/status
```

### 7. Secure Admin API via Data Plane

```bash
# Create admin API service
curl -X POST http://config.kong.local:8001/services \
  --data name=admin-api \
  --data url=http://config.kong.local:8001

# Create route
curl -X POST http://config.kong.local:8001/services/admin-api/routes \
  --data 'paths[]=/admin-api' \
  --data strip_path=true

# Enable API key auth
curl -X POST http://config.kong.local:8001/services/admin-api/plugins \
  --data name=key-auth \
  --data config.key_names[]=apikey

# Create consumer and key
curl -X POST http://config.kong.local:8001/consumers --data username=admin-user
curl -X POST http://config.kong.local:8001/consumers/admin-user/key-auth \
  --data key=YOUR-SECURE-API-KEY

# Enable IP restriction
curl -X POST http://config.kong.local:8001/services/admin-api/plugins \
  --data name=ip-restriction \
  --data config.allow[]=203.0.113.0/24

# Enable rate limiting
curl -X POST http://config.kong.local:8001/services/admin-api/plugins \
  --data name=rate-limiting \
  --data config.minute=100
```

Test:
```bash
curl -H "apikey: YOUR-SECURE-API-KEY" http://<alb-dns>/admin-api/status
```

## Configuration Reference

### Control Plane Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| KONG_ROLE | control_plane | Role mode |
| KONG_DATABASE | postgres | Database type |
| KONG_PG_HOST | <endpoint> | Aurora endpoint |
| KONG_PG_PORT | 5432 | PostgreSQL port |
| KONG_PG_DATABASE | kong | Database name |
| KONG_ADMIN_LISTEN | 0.0.0.0:8001 | Admin API |
| KONG_CLUSTER_LISTEN | 0.0.0.0:8005 | Cluster endpoint |
| KONG_CLUSTER_CERT | /etc/kong/certs/cluster.crt | Cert path |
| KONG_CLUSTER_CERT_KEY | /etc/kong/certs/cluster.key | Key path |

### Data Plane Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| KONG_ROLE | data_plane | Role mode |
| KONG_DATABASE | off | DB-less mode |
| KONG_PROXY_LISTEN | 0.0.0.0:8000 | Proxy port |
| KONG_CLUSTER_CONTROL_PLANE | config.kong.local:8005 | CP endpoint |
| KONG_CLUSTER_SERVER_NAME | config.kong.local | SNI name |
| KONG_CLUSTER_CERT | /etc/kong/certs/cluster.crt | Cert path |
| KONG_CLUSTER_CERT_KEY | /etc/kong/certs/cluster.key | Key path |

## Troubleshooting

### DP Cannot Connect to CP
1. Check service discovery: `nslookup config.kong.local`
2. Verify security groups allow port 8005
3. Check cluster certificates match
4. View logs: `aws logs tail /fargate/kong-dataplane-logs`

### CP Database Connection Failed
1. Verify Aurora endpoint in task definition
2. Check security group allows port 5432 from CP
3. Verify credentials in Secrets Manager
4. Ensure migrations completed successfully

### Admin API Not Accessible
1. Verify route exists: `curl http://config.kong.local:8001/routes`
2. Check plugin configuration
3. Validate API key
4. Verify ALB health checks passing
