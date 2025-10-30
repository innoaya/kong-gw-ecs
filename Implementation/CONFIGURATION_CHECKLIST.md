# Configuration Checklist

Use this checklist to ensure all required values are configured before deployment.

## Task Definition Configuration

### kong-cp-task-definition.json (Control Plane)

- [ ] **AWS Account ID** (2 locations)
  - `executionRoleArn`: Replace `<YOUR_AWS_ACCOUNT_ID>` with your AWS account ID
  - `taskRoleArn`: Replace `<YOUR_AWS_ACCOUNT_ID>` with your AWS account ID

- [ ] **Aurora PostgreSQL Endpoint**
  - `KONG_PG_HOST`: Replace `<YOUR_AURORA_ENDPOINT>` with your Aurora endpoint
  - Example: `kong-db.cluster-xxxxx.ap-southeast-1.rds.amazonaws.com`

- [ ] **Database Credentials**
  - `KONG_PG_USER`: Replace `<YOUR_DB_USERNAME>` with your database username
  - `KONG_PG_PASSWORD`: Replace `<YOUR_DB_PASSWORD>` with your database password

- [ ] **Cluster Certificates**
  - `CLUSTER_CERT_CONTENT`: Paste content from `CLUSTER_CERT_CONTENT.txt`
  - `CLUSTER_KEY_CONTENT`: Paste content from `CLUSTER_KEY_CONTENT.txt`

### kong-dp-task-definition.json (Data Plane)

- [ ] **AWS Account ID** (2 locations)
  - `executionRoleArn`: Replace `<YOUR_AWS_ACCOUNT_ID>` with your AWS account ID
  - `taskRoleArn`: Replace `<YOUR_AWS_ACCOUNT_ID>` with your AWS account ID

- [ ] **Cluster Certificates**
  - `CLUSTER_CERT_CONTENT`: Paste content from `CLUSTER_CERT_CONTENT.txt`
  - `CLUSTER_KEY_CONTENT`: Paste content from `CLUSTER_KEY_CONTENT.txt`

### kong-migrations-task-definition.json (Migrations)

- [ ] **AWS Account ID** (2 locations)
  - `executionRoleArn`: Replace `<YOUR_AWS_ACCOUNT_ID>` with your AWS account ID
  - `taskRoleArn`: Replace `<YOUR_AWS_ACCOUNT_ID>` with your AWS account ID

- [ ] **Aurora PostgreSQL Endpoint**
  - `KONG_PG_HOST`: Replace `<YOUR_AURORA_ENDPOINT>` with your Aurora endpoint

- [ ] **Database Credentials**
  - `KONG_PG_USER`: Replace `<YOUR_DB_USERNAME>` with your database username
  - `KONG_PG_PASSWORD`: Replace `<YOUR_DB_PASSWORD>` with your database password

## ✅ Script Configuration

### run-migrations.sh

- [ ] **Subnet ID**
  - Update `SUBNET_ID` with your private subnet ID

- [ ] **Security Group**
  - Update `SECURITY_GROUP` with your control plane security group ID

### verify-deployment.sh

- [ ] No configuration needed

## ✅ IAM Task Role Policy

- [ ] **Update iam-task-role-policy.json**
  - Replace `<YOUR_AWS_ACCOUNT_ID>` with your AWS account ID in the policy JSON

- [ ] **Add inline policy to kong-gw-TaskRole**
  - Navigate to IAM → Roles → kong-gw-TaskRole
  - Add permissions → Create inline policy
  - Paste JSON from iam-task-role-policy.json
  - Policy name: `KongECSExecPolicy`

## ✅ Certificate Generation

- [ ] Run `./generate-shared-mtls-cert.sh` to generate certificates
- [ ] Verify `CLUSTER_CERT_CONTENT.txt` exists
- [ ] Verify `CLUSTER_KEY_CONTENT.txt` exists
- [ ] Copy certificate contents to task definitions

## ✅ AWS Resources (Prerequisites)

- [ ] VPC created with public and private subnets
- [ ] Security Groups configured:
  - Control Plane SG (allow 8001, 8005)
  - Data Plane SG (allow 8000)
  - Aurora SG (allow 5432)
  - ALB SG (allow 80, 443)
- [ ] IAM Roles created:
  - `ecsTaskExecutionRole`
  - `kong-gw-TaskRole`
- [ ] CloudWatch Log Groups created:
  - `/fargate/kong-controlplane-logs`
  - `/fargate/kong-dataplane-logs`
  - `/fargate/kong-migrations`
- [ ] Aurora PostgreSQL cluster created
  - Database name: `kong`
  - Endpoint recorded
- [ ] ECS Cluster created
- [ ] Service Discovery namespace created (`kong.local`)

## ✅ Security Recommendations

- [ ] Store database credentials in AWS Secrets Manager
- [ ] Enable Aurora encryption at rest
- [ ] Use HTTPS on ALB with ACM certificate
- [ ] Configure AWS WAF on ALB
- [ ] Set up CloudWatch alarms
- [ ] Review security group rules
- [ ] Generate strong API keys for admin API

## ✅ Post-Deployment

- [ ] Run database migrations using `./run-migrations.sh`
- [ ] Verify migrations completed successfully
- [ ] Deploy Control Plane service
- [ ] Verify Control Plane is healthy
- [ ] Deploy Data Plane service
- [ ] Verify Data Plane is healthy
- [ ] Check cluster connectivity
- [ ] Configure admin API security plugins
- [ ] Test admin API access
- [ ] Run `./verify-deployment.sh` to check overall health

## Quick Reference

### Find Your AWS Account ID
```bash
aws sts get-caller-identity --query Account --output text
```

### Find Your Aurora Endpoint
```bash
aws rds describe-db-clusters \
  --db-cluster-identifier kong-gw-uat \
  --query 'DBClusters[0].Endpoint' \
  --output text
```

### Find Your Subnet IDs
```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=<your-vpc-id>" \
  --query 'Subnets[*].[SubnetId,Tags[?Key==`Name`].Value|[0],AvailabilityZone]' \
  --output table
```

### Find Your Security Group IDs
```bash
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=<your-vpc-id>" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' \
  --output table
```
