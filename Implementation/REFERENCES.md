# References

This document provides authoritative sources for all technical concepts, configurations, and best practices used in this Kong Gateway deployment documentation.

## Kong Gateway

### Official Documentation
- **Kong Gateway Overview**  
  https://docs.konghq.com/gateway/latest/

- **Kong Gateway Hybrid Mode**  
  https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/

- **Kong Admin API Reference**  
  https://docs.konghq.com/gateway/latest/admin-api/

- **Kong Configuration Reference**  
  https://docs.konghq.com/gateway/latest/reference/configuration/

- **Kong Database Support**  
  https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-mode/

- **Kong Migrations**  
  https://docs.konghq.com/gateway/latest/install/migrations/

- **Kong Clustering & Data Planes**  
  https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/clustering/

- **Kong mTLS (Mutual TLS) for Hybrid Mode**  
  https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/setup/#generate-certificate-key-pairs

### Kong Plugins
- **Key Authentication Plugin**  
  https://docs.konghq.com/hub/kong-inc/key-auth/

- **IP Restriction Plugin**  
  https://docs.konghq.com/hub/kong-inc/ip-restriction/

- **Rate Limiting Plugin**  
  https://docs.konghq.com/hub/kong-inc/rate-limiting/

- **Prometheus Plugin**  
  https://docs.konghq.com/hub/kong-inc/prometheus/

## AWS ECS (Elastic Container Service)

### Core ECS Documentation
- **Amazon ECS Documentation**  
  https://docs.aws.amazon.com/ecs/

- **AWS Fargate for ECS**  
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html

- **ECS Task Definitions**  
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html

- **ECS Services**  
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html

- **ECS Task Networking**  
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-networking.html

- **ECS Best Practices Guide**  
  https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/

### ECS Exec & Debugging
- **ECS Exec Documentation**  
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html

- **Using ECS Exec for Debugging**  
  https://aws.amazon.com/blogs/containers/new-using-amazon-ecs-exec-access-your-containers-fargate-ec2/

- **AWS Session Manager Plugin Installation**  
  https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

### ECS IAM
- **ECS Task IAM Roles**  
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html

- **ECS Task Execution Role**  
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html

## AWS Aurora & RDS

### Aurora Serverless v2
- **Amazon Aurora Serverless v2 Documentation**  
  https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html

- **Aurora Serverless v2 Requirements**  
  https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.requirements.html

- **Aurora Serverless v2 Scaling**  
  https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.setting-capacity.html

- **Aurora PostgreSQL Documentation**  
  https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.AuroraPostgreSQL.html

### RDS Security
- **Amazon RDS Security**  
  https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.html

- **RDS DB Subnet Groups**  
  https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html#USER_VPC.Subnets

## AWS Networking

### VPC (Virtual Private Cloud)
- **Amazon VPC Documentation**  
  https://docs.aws.amazon.com/vpc/

- **VPC Security Best Practices**  
  https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html

- **VPC Subnets**  
  https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html

- **Internet Gateways**  
  https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html

- **NAT Gateways**  
  https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html

- **Route Tables**  
  https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html

### Security Groups
- **Security Groups for Your VPC**  
  https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html

- **Security Group Rules**  
  https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html

## AWS Load Balancing

### Application Load Balancer (ALB)
- **Application Load Balancer Documentation**  
  https://docs.aws.amazon.com/elasticloadbalancing/latest/application/

- **Target Groups for ALB**  
  https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html

- **Health Checks for ALB**  
  https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html

- **ALB Listeners**  
  https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html

## AWS Service Discovery

### AWS Cloud Map
- **AWS Cloud Map Documentation**  
  https://docs.aws.amazon.com/cloud-map/

- **Service Discovery with ECS**  
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html

- **Creating Service Discovery Services**  
  https://docs.aws.amazon.com/cloud-map/latest/dg/working-with-services.html

## AWS IAM (Identity & Access Management)

### IAM Documentation
- **AWS IAM Documentation**  
  https://docs.aws.amazon.com/iam/

- **IAM Policies and Permissions**  
  https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html

- **IAM Roles**  
  https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html

- **IAM Best Practices**  
  https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html

## AWS CloudWatch

### Monitoring & Logging
- **Amazon CloudWatch Documentation**  
  https://docs.aws.amazon.com/cloudwatch/

- **CloudWatch Logs**  
  https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html

- **CloudWatch Logs with ECS**  
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_cloudwatch_logs.html

## AWS Secrets Manager

### Secrets Management
- **AWS Secrets Manager Documentation**  
  https://docs.aws.amazon.com/secretsmanager/

- **Using Secrets Manager with ECS**  
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-secrets.html

## Security & Cryptography

### TLS/SSL & mTLS
- **Mutual TLS (mTLS) Overview**  
  https://www.cloudflare.com/learning/access-management/what-is-mutual-tls/

- **OpenSSL Documentation**  
  https://www.openssl.org/docs/

- **X.509 Certificates**  
  https://datatracker.ietf.org/doc/html/rfc5280

### Security Best Practices
- **AWS Well-Architected Framework - Security Pillar**  
  https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html

- **OWASP API Security Top 10**  
  https://owasp.org/www-project-api-security/

- **CIS AWS Foundations Benchmark**  
  https://www.cisecurity.org/benchmark/amazon_web_services

## PostgreSQL

### PostgreSQL Documentation
- **PostgreSQL Official Documentation**  
  https://www.postgresql.org/docs/

- **PostgreSQL 15 Documentation**  
  https://www.postgresql.org/docs/15/

- **psql Command Line Tool**  
  https://www.postgresql.org/docs/current/app-psql.html

## AWS CLI

### AWS CLI Reference
- **AWS CLI Documentation**  
  https://docs.aws.amazon.com/cli/

- **AWS CLI Command Reference - ECS**  
  https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ecs/index.html

- **AWS CLI Command Reference - RDS**  
  https://awscli.amazonaws.com/v2/documentation/api/latest/reference/rds/index.html

## Container & Docker

### Docker Documentation
- **Docker Official Documentation**  
  https://docs.docker.com/

- **Docker Container Networking**  
  https://docs.docker.com/network/

- **Dockerfile Best Practices**  
  https://docs.docker.com/develop/develop-images/dockerfile_best-practices/

## Infrastructure as Code

### Terraform (Optional)
- **Terraform AWS Provider**  
  https://registry.terraform.io/providers/hashicorp/aws/latest/docs

- **Terraform ECS Module**  
  https://registry.terraform.io/modules/terraform-aws-modules/ecs/aws/latest

### AWS CloudFormation (Optional)
- **AWS CloudFormation Documentation**  
  https://docs.aws.amazon.com/cloudformation/

## API Gateway Concepts

### API Gateway Patterns
- **API Gateway Pattern**  
  https://microservices.io/patterns/apigateway.html

- **Backend for Frontend (BFF) Pattern**  
  https://samnewman.io/patterns/architectural/bff/

## Books & Additional Resources

### Recommended Reading
- **"Building Microservices" by Sam Newman**  
  O'Reilly Media, 2021  
  ISBN: 978-1492034025

- **"AWS Certified Solutions Architect Study Guide"**  
  Sybex, 2023  
  ISBN: 978-1119982623

- **"Site Reliability Engineering" by Google**  
  Free online: https://sre.google/books/

### Kong Resources
- **Kong Blog - Hybrid Mode**  
  https://konghq.com/blog/kong-gateway-hybrid-mode

- **Kong Community Forum**  
  https://discuss.konghq.com/

### AWS Architecture
- **AWS Architecture Center**  
  https://aws.amazon.com/architecture/

- **AWS Solutions Library**  
  https://aws.amazon.com/solutions/

## Pricing Information

### AWS Pricing
- **AWS Fargate Pricing**  
  https://aws.amazon.com/fargate/pricing/

- **Amazon Aurora Pricing**  
  https://aws.amazon.com/rds/aurora/pricing/

- **Application Load Balancer Pricing**  
  https://aws.amazon.com/elasticloadbalancing/pricing/

- **AWS Pricing Calculator**  
  https://calculator.aws/

## Region-Specific Information

### Asia Pacific (Singapore) - ap-southeast-1
- **AWS Regional Services**  
  https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/

- **AWS Singapore Region**  
  https://aws.amazon.com/about-aws/global-infrastructure/regions_az/

## Compliance & Standards

### Compliance Resources
- **AWS Compliance Programs**  
  https://aws.amazon.com/compliance/programs/

- **AWS Shared Responsibility Model**  
  https://aws.amazon.com/compliance/shared-responsibility-model/

- **SOC 2 Compliance**  
  https://aws.amazon.com/compliance/soc-2-faqs/

---

**Note**: All links were verified as of October 2025. AWS documentation and Kong documentation are continuously updated. Always refer to the latest official documentation for the most current information.

**Verification**: All technical implementations in this repository follow the official documentation and best practices from the sources listed above.
