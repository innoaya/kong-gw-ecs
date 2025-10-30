# AWS Services Inventory for Kong Gateway ECS + Aurora Serverless Architecture

This document lists all AWS services used in the **Kong Gateway ECS + Aurora Serverless v2 Architecture**, annotated with **(Optional)** where the service is *not strictly required* for the current minimal, cost-optimized design.

**Related Documentation:**
- [Architecture Overview](./README.md)
- [Cost Estimation](./COST-ESTIMATION.md)
- [Implementation Guide](./Implementation/README.md)

---

## 1. Networking & Routing

| Service | Purpose |
|----------|----------|
| **Amazon VPC** | Provides private network isolation for ECS tasks, Aurora DB, and service discovery. |
| **Subnets (Public & Private)** | Public subnets host ALB; private subnets host ECS tasks and Aurora. |
| **Route Tables** | Manage routing between public and private subnets. |
| **Internet Gateway (IGW)** | Enables outbound internet access for ALB. |
| **NAT Gateway (Optional)** | Needed only if ECS tasks in private subnets must access the internet directly. |
| **AWS Route 53** | Manages DNS records (e.g., `kong-gw.example.com`). |
| **AWS Cloud Map (Namespace)** | Enables internal ECS service discovery (`kong-cp.namespace.local`). |
| **Security Groups (SGs)** | Control inbound/outbound traffic between ALB, ECS tasks, and Aurora. |
| **Network ACLs (Optional)** | Extra subnet-level security control (not required for current design). |

---

## 2. Compute & Container Orchestration

| Service | Purpose |
|----------|----------|
| **Amazon ECS (Fargate)** | Runs Control Plane (CP) and Data Plane (DP) containers serverlessly. |
| **ECS Services** | Maintain desired task counts and apply scaling policies. |
| **ECS Task Definitions** | Define containers, ports, environment variables, and IAM roles. |
| **ECS Auto Scaling** | Scales Data Plane tasks based on CloudWatch metrics. |
| **ECS Service Discovery (Cloud Map)** | Resolves Control Plane DNS internally for mTLS and Admin API access. |

---

## 3. Database & Storage

| Service | Purpose |
|----------|----------|
| **Amazon Aurora Serverless v2 (PostgreSQL)** | Primary config database for Kong Control Plane; auto-scales to 0 ACU. |
| **Amazon RDS Proxy (Optional)** | Improves connection pooling if Control Plane activity increases. |
| **Amazon S3 (Optional)** | Used only if ALB or CloudWatch logs need to be archived. |

---

## 4. Load Balancing & Traffic Management

| Service | Purpose |
|----------|----------|
| **Application Load Balancer (ALB)** | Single entrypoint for all traffic (`kong-gw.example.com`). |
| **ALB Target Group** | Routes incoming HTTPS requests to ECS Data Plane tasks. |
| **ALB Listener Rules** | Forwards all HTTPS traffic (port 443 → DP TG). |
| **AWS Certificate Manager (ACM)** | Manages SSL/TLS certificates for `*.example.com`. |

---

## 5. Security, Authentication & Compliance

| Service | Purpose |
|----------|----------|
| **AWS Identity and Access Management (IAM)** | Provides Task Roles and Execution Roles for ECS tasks. |
| **AWS Secrets Manager** | Stores Aurora credentials and API keys securely. |
| **AWS WAF (Optional)** | Protects ALB from web exploits if exposed to public internet. |
| **AWS Shield (Standard)** | Provides baseline DDoS protection (default for ALB). |
| **API Key Authentication (Kong Plugin)** | Secures `/kong-admin` route for Control Plane proxy. |
| **IP Restriction (Kong Plugin)** | Restricts `/kong-admin` route to trusted admin IPs. |

---

## 6. Monitoring, Logging & Observability

| Service | Purpose |
|----------|----------|
| **Amazon CloudWatch Logs** | Collects ECS logs for both CP and DP tasks. |
| **Amazon CloudWatch Metrics** | Monitors ECS resource utilization and Aurora ACUs. |
| **Amazon CloudWatch Alarms** | Triggers Control Plane start/stop or scaling events. |
| **AWS CloudTrail (Optional)** | Audits API calls for compliance and governance. |
| **Amazon S3 (Optional)** | Stores ALB or CloudWatch log archives if long-term retention is needed. |

---

## 7. Automation & Scaling Coordination

| Service | Purpose |
|----------|----------|
| **Amazon EventBridge (Optional)** | Triggers ECS service actions (e.g., start Control Plane on scale-up). |
| **AWS Lambda (Optional)** | Executes automation logic for ECS lifecycle or scaling. |
| **ECS Auto Scaling Policies** | Automatically scale Data Plane tasks based on traffic and metrics. |

---

## 8. Developer & Operations Tools

| Service | Purpose |
|----------|----------|
| **AWS Systems Manager (Parameter Store)** | Alternative lightweight config storage. |
| **AWS Config (Optional)** | Detects infrastructure configuration drift. |
| **AWS Budgets / Cost Explorer** | Monitors and forecasts service usage and costs. |
| **AWS CodePipeline / CodeBuild (Optional)** | Automates ECS image builds and deployments. |

---

## ✅ Core Required Stack

| Category | Essential Services |
|-----------|--------------------|
| **Networking** | VPC, Subnets, Route 53, Cloud Map, Security Groups |
| **Compute** | ECS (Fargate), ECS Service, ECS Task Definition |
| **Database** | Aurora Serverless v2 (PostgreSQL) |
| **Traffic** | ALB, Target Group, ACM |
| **Security** | IAM, Secrets Manager, API Key + IP Restriction |
| **Monitoring** | CloudWatch (Logs, Metrics, Alarms) |

All other services are **optional extensions** for automation, compliance, or scaling enhancements.

---

**← Back to [Architecture Overview](./README.md)**
