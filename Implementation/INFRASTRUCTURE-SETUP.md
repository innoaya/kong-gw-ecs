# AWS Infrastructure Setup Guide

Step-by-step instructions to create all required AWS infrastructure using the **AWS Management Console**.

## Required AWS Resources

- VPC with public and private subnets (single AZ)
- Internet Gateway
- Route Tables
- Security Groups (4): ALB, Data Plane, Control Plane, Aurora
- IAM Roles: ecsTaskExecutionRole, kong-gw-TaskRole
- CloudWatch Log Groups (3)
- Aurora Serverless v2 PostgreSQL cluster
- ECS Cluster
- Service Discovery (Cloud Map) namespace and service
- Application Load Balancer + Target Group
- ACM Certificate (optional - for HTTPS)
- Route53 Record (optional - for custom domain)

---

## Step-by-Step Setup

### 1. **Create VPC with VPC Wizard**

**Navigation**: AWS Console → VPC → Create VPC

1. **VPC settings**:
   - Select: **"VPC and more"** (recommended - creates everything automatically)
   - Name tag: `kong-gw-vpc`
   - IPv4 CIDR: `10.0.0.0/16`

2. **Availability Zones (AZs)**: Select **1** (cost-optimized)

3. **Number of public subnets**: **1**
   - Public subnet CIDR block: `10.0.1.0/24`

4. **Number of private subnets**: **1**
   - Private subnet CIDR block: `10.0.11.0/24`

5. **NAT gateways**: Select **None**

6. **VPC endpoints**: **None**

7. **DNS options**:
   - Enable DNS hostnames: Yes
   - Enable DNS resolution: Yes

8. Click **Create VPC**

📝 **Record these values**:
- VPC ID
- Public Subnet ID
- Private Subnet ID

---

### 2. **Create Security Groups**

**Navigation**: AWS Console → VPC → Security Groups → Create security group

Create 4 security groups in your VPC:

#### **A. ALB Security Group** (`kong-alb-sg`)
- **Name**: `kong-alb-sg`
- **Description**: Security group for Application Load Balancer
- **VPC**: Select your Kong VPC
- **Inbound rules**:
  | Type | Protocol | Port | Source | Description |
  |------|----------|------|--------|-------------|
  | HTTP | TCP | 80 | 0.0.0.0/0 | Allow HTTP from internet |
  | HTTPS | TCP | 443 | 0.0.0.0/0 | Allow HTTPS from internet |
- **Outbound rules**: Keep default (all traffic)

#### **B. Data Plane Security Group** (`kong-data-plane-sg`)
- **Name**: `kong-data-plane-sg`
- **Description**: Security group for Kong Data Plane
- **VPC**: Select your Kong VPC
- **Inbound rules**:
  | Type | Protocol | Port | Source | Description |
  |------|----------|------|--------|-------------|
  | Custom TCP | TCP | 8000 | kong-alb-sg | Allow proxy traffic from ALB |
- **Outbound rules**: Keep default (all traffic)

#### **C. Control Plane Security Group** (`kong-control-plane-sg`)
- **Name**: `kong-control-plane-sg`
- **Description**: Security group for Kong Control Plane
- **VPC**: Select your Kong VPC
- **Inbound rules**:
  | Type | Protocol | Port | Source | Description |
  |------|----------|------|--------|-------------|
  | Custom TCP | TCP | 8001 | kong-data-plane-sg | Admin API from Data Plane |
  | Custom TCP | TCP | 8005 | kong-data-plane-sg | Cluster sync from Data Plane |
- **Outbound rules**: Keep default (all traffic)

#### **D. Aurora Security Group** (`kong-aurora-sg`)
- **Name**: `kong-aurora-sg`
- **Description**: Security group for Aurora PostgreSQL
- **VPC**: Select your Kong VPC
- **Inbound rules**:
  | Type | Protocol | Port | Source | Description |
  |------|----------|------|--------|-------------|
  | PostgreSQL | TCP | 5432 | kong-control-plane-sg | Allow DB access from Control Plane |
- **Outbound rules**: Keep default (all traffic)

📝 **Record all Security Group IDs** - you'll need these later.

---

### 3. **Create Aurora Serverless v2 PostgreSQL**

**Navigation**: AWS Console → RDS → Create database

1. **Choose a database creation method**: Standard create

2. **Engine options**:
   - Engine type: **Aurora (PostgreSQL Compatible)**
   - Engine version: **Aurora PostgreSQL 15.4** (or latest Serverless v2 compatible)

3. **Templates**: **Production** or **Dev/Test**

4. **Settings**:
   - DB cluster identifier: `kong-gw-aurora`
   - Master username: `kongadmin`
   - Master password: (set a strong password)
   - Confirm password

5. **DB instance class**: Select **Serverless v2**

6. **Availability & durability**:
   - Don't create an Aurora Replica (optional - can add later)

7. **Connectivity**:
   - Virtual private cloud (VPC): Select your Kong VPC
   - DB subnet group: Create new (it will auto-select your private subnets)
   - Public access: **No**
   - VPC security group: **Choose existing** → Select `kong-aurora-sg`

8. **Serverless v2 capacity settings**:
   - Minimum ACUs: **0** (scales to $0 when idle!)
   - Maximum ACUs: **2** (adjust based on your needs)

9. **Additional configuration**:
   - Initial database name: **kong**
   - Backup retention period: 7 days
   - Enable encryption: ✅
   - CloudWatch Logs: ✅ PostgreSQL log

10. Click **Create database**

⏱️ **Wait 5-10 minutes** for database to become available.

📝 **Record the database endpoint** (e.g., `kong-gw-aurora.cluster-xxxxx.ap-southeast-1.rds.amazonaws.com`)

---

### 4. **Create IAM Roles**

**Navigation**: AWS Console → IAM → Roles → Create role

ECS requires two IAM roles:
- **Task Execution Role**: Used by ECS to pull container images and write logs
- **Task Role**: Used by the container application to access AWS services

#### **A. ECS Task Execution Role** (`ecsTaskExecutionRole`)

**Purpose**: Allows ECS to pull images from ECR and write logs to CloudWatch.

1. **Select trusted entity**: AWS service
2. **Use case**: Elastic Container Service → Elastic Container Service Task
3. **Add permissions**: Search and select `AmazonECSTaskExecutionRolePolicy`
4. **Role name**: `ecsTaskExecutionRole`
5. **Role description**: ECS Task Execution Role for Kong Gateway
6. Click **Create role**

**Policy attached**: AWS managed `AmazonECSTaskExecutionRolePolicy`

#### **B. Kong Task Role** (`kong-gw-TaskRole`)

**Purpose**: Allows Kong containers to use ECS Exec for debugging.

1. **Select trusted entity**: AWS service
2. **Use case**: Elastic Container Service → Elastic Container Service Task
3. **Add permissions**: Skip for now
4. **Role name**: `kong-gw-TaskRole`
5. **Role description**: Kong Gateway Task Role
6. Click **Create role**

7. **Add custom policy for ECS Exec**:
   - Go to the role → **Add permissions** → **Create inline policy**
   - Switch to **JSON** tab
   - Paste content from `iam-task-role-policy.json`
   - **Important**: Replace `<YOUR_AWS_ACCOUNT_ID>` with your AWS account ID
   - Policy name: `KongECSExecPolicy`
   - Click **Create policy**

**Policy grants**:
- SSM Session Manager access (for ECS Exec)
- CloudWatch Logs write (for exec session logs)

📝 **Record both Role ARNs** - you'll need these in task definitions.

---

### 5. **Create CloudWatch Log Groups**

**Navigation**: AWS Console → CloudWatch → Logs → Log groups → Create log group

Create 3 log groups:

1. **Control Plane Logs**:
   - Log group name: `/fargate/kong-controlplane-logs`
   - Retention: 7 days
   - Click **Create**

2. **Data Plane Logs**:
   - Log group name: `/fargate/kong-dataplane-logs`
   - Retention: 7 days
   - Click **Create**

3. **Migrations Logs**:
   - Log group name: `/fargate/kong-migrations`
   - Retention: 7 days
   - Click **Create**

---

### 6. **Create ECS Cluster**

**Navigation**: AWS Console → ECS → Clusters → Create cluster

1. **Cluster name**: `kong-gateway-cluster`
2. **Infrastructure**: AWS Fargate (serverless)
3. **Monitoring**: ✅ Use Container Insights (optional - costs extra)
4. Click **Create**

---

### 7. **Create Service Discovery (Cloud Map)**

**Navigation**: AWS Console → Cloud Map → Create namespace

1. **Create namespace**:
   - Namespace type: **Private DNS namespace**
   - Namespace name: `kong.local`
   - VPC: Select your Kong VPC
   - Click **Create namespace**

2. **Create service** (after namespace is created):
   - Navigate to: Cloud Map → Namespaces → kong.local → Create service
   - Service name: `config`
   - Service discovery configuration:
     - DNS record type: **A**
     - TTL: **10** seconds
   - Health check: **Custom health check**
   - Failure threshold: **1**
   - Click **Create service**

📝 **Record**: Control Plane will be accessible at `config.kong.local`

---

### 8. **Create Application Load Balancer**

**Navigation**: AWS Console → EC2 → Load Balancers → Create load balancer

1. **Load balancer type**: Application Load Balancer → **Create**

2. **Basic configuration**:
   - Load balancer name: `kong-gw-alb`
   - Scheme: **Internet-facing**
   - IP address type: IPv4

3. **Network mapping**:
   - VPC: Select your Kong VPC
   - Mappings: Select **your public subnet** (single AZ for cost optimization)

4. **Security groups**:
   - Select: `kong-alb-sg`

5. **Listeners and routing**:
   - Protocol: HTTP, Port: 80
   - Default action: **Create target group** (opens new tab)

6. **Create target group** (in new tab):
   - Target type: **IP addresses**
   - Target group name: `kong-data-plane-tg`
   - Protocol: HTTP
   - Port: **8000**
   - VPC: Select your Kong VPC
   - Protocol version: HTTP1
   - Health checks:
     - Health check path: `/status`
     - Interval: 30 seconds
     - Timeout: 5 seconds
     - Healthy threshold: 2
     - Unhealthy threshold: 3
   - Click **Next**, then **Create target group**

7. Go back to ALB creation tab:
   - Refresh target groups
   - Select: `kong-data-plane-tg`

8. Click **Create load balancer**

📝 **Record the ALB DNS name** (e.g., `kong-gw-alb-1234567890.ap-southeast-1.elb.amazonaws.com`)

---

## Values to Record

After creating infrastructure, record these values for task definitions:

```bash
# Update in task definition files:
- AWS_ACCOUNT_ID: <your-account-id>
- AURORA_ENDPOINT: <aurora-endpoint>.rds.amazonaws.com
- DB_USERNAME: kongadmin
- DB_PASSWORD: <your-password>

# Update in scripts:
- VPC_ID: vpc-xxxxx
- PRIVATE_SUBNET_IDS: subnet-xxxxx, subnet-yyyyy
- CONTROL_PLANE_SG: sg-xxxxx
- DATA_PLANE_SG: sg-xxxxx
```

## Next Steps

After infrastructure is created, proceed to `DEPLOYMENT.md` for:
1. Database migration
2. Control Plane deployment
3. Data Plane deployment
4. Admin API configuration

## Common Issues

**Aurora not connecting**:
- Check security group allows port 5432 from Control Plane SG
- Verify DB subnet group includes private subnets
- Confirm Aurora is in "Available" state

**Aurora cold start delay** (0 ACU minimum):
- First connection after idle takes 15-30 seconds
- Monitor `ServerlessDatabaseCapacity` in CloudWatch

**ALB not accessible**:
- Verify Internet Gateway is attached to VPC
- Check route table has 0.0.0.0/0 → IGW route
- Confirm ALB security group allows ports 80/443
