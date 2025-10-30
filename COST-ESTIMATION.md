# Kong Gateway – AWS Cost & Transaction Estimate (Singapore Region)

This document estimates monthly cost and throughput for the **Event-Driven Kong Gateway Architecture**
deployed on **AWS ECS Fargate + Aurora Serverless v2 (PostgreSQL)** in the **ap-southeast-1 (Singapore)** region.

**Related Documentation:**
- [Architecture Overview](./README.md)
- [AWS Services Inventory](./AWS-SERVICES.md)
- [Implementation Guide](./Implementation/README.md)

---

## Architecture Summary

| Component | Mode | Behavior |
|------------|------|-----------|
| **Data Plane (DP)** | ECS Fargate | Always on – handles API traffic |
| **Control Plane (CP)** | ECS Fargate | Auto-start on scale/config, stops after cooldown |
| **Aurora Serverless v2 (Postgres)** | Min 0 ACU | Auto-pause (0 ACU when idle) |
| **ALB** | Public | Handles HTTPS to DP |
| **Route 53 + CloudWatch** | — | DNS + logs |

---

## AWS Service Rates (Singapore Region)

| Service | Rate |
|----------|------|
| **Aurora Serverless v2** | **$0.20 / ACU-hour** |
| **ECS Fargate (x86)** | **$0.05056 / vCPU-hour**, **$0.00553 / GB-hour** |
| **Storage (Aurora)** | **$0.115 / GB-month** |
| **ALB** | **$0.025 / hr base + $0.008 / LCU-hr (≈ fixed)** |
| **Route 53 + CloudWatch** | ~**$3.5 / month** |

---

## Monthly Cost Estimate (25 KB Payload)

| Scenario | CP+Aurora Active Time | **ALB (Fixed)** | **DP Fargate (1 vCPU + 2 GB)** | **CP Fargate (0.25 vCPU + 0.5 GB)** | **Aurora Compute (1 ACU)** | **Aurora Storage (20 GB)** | **Route 53 + CW** | **Total (USD)** |
|-----------|---------------------:|----------------:|--------------------------------:|------------------------------------:|----------------------------:|--------------------------:|-----------------:|---------------:|
| **A – Low load (UAT)** | 2 h/day | $20 | $10.7 | $0.9 | $12.0 | $2.3 | $3.5 | **$49** |
| **B – Medium load (Prod)** | 6 h/day | $20 | $10.7 | $2.6 | $36.0 | $2.3 | $3.5 | **$76** |
| **C – Heavy load** | 12 h/day | $20 | $10.7 | $5.2 | $72.0 | $2.3 | $3.5 | **$114** |
| **D – Full load (24 h/day)** | 24 h/day | $20 | $10.7 | $10.4 | $144.0 | $2.3 | $3.5 | **$191** |

> 💡 **Assumptions**  
> • ECS Fargate vCPU cost $0.05056/hr + Memory $0.00553/GB-hr  
> • DP task runs 24×7 (steady traffic)  
> • CP task starts automatically on updates or scale events, then stops after cooldown  
> • Aurora Serverless v2 = 1 ACU @ $0.20/hr (2 GB RAM equiv)  
> • Aurora Storage ≈ 20 GB @ $0.115/GB-month  
> • ALB base $0.025/hr + minimal LCU usage (~$1–2/month, effectively fixed)  
> • Route 53 + CloudWatch ≈ $3.5 flat monthly  

---

## Transaction Throughput (25 KB avg payload)

At 0.1 LCU/hr (≈ 0.1 GB/hr ≈ 28 KB/s):

| Payload | TPS | Tx / Month (30 days) |
|----------|----:|---------------------:|
| 25 KB (standard) | ≈ 1.1 | ≈ 2.9 M |
| 10 KB (light) | ≈ 2.8 | ≈ 7.3 M |
| 50 KB (heavy) | ≈ 0.56 | ≈ 1.4 M |

---

## Cost Efficiency (25 KB payload)

| Scenario | Monthly Cost | Tx / Month | Cost / 1 M Tx |
|-----------|--------------:|------------:|---------------:|
| A – Low load | $49 | 2.9 M | $17 / M tx |
| B – Medium load | $76 | 4.4 M | $17 / M tx |
| C – Heavy load | $114 | 7.2 M | $16 / M tx |
| D – Full load | $191 | 14.4 M | $13 / M tx |

---

## Observations

- **Aurora cost dominates** during active periods ($0.20 / ACU-hr).  
- **Auto-pause Aurora** and **event-driven CP start** save ~70% vs always-on.  
- **DP + ALB base floor ≈ $30/mo**, keeping system always reachable.  
- **Cost per 1M transactions** improves at higher utilization (economy of scale).  
- **Idle cost ≈ $25/mo** (ALB + storage + DNS/metrics).

---

## Cost vs Transaction Chart (Markdown Table)

| Scenario | Transaction Volume (M/month) | Cost (USD) |
|-----------|-----------------------------:|-----------:|
| **A – UAT / Low Load** | 2.9 | $49 |
| **B – Prod / Medium** | 4.4 | $76 |
| **C – Heavy Load** | 7.2 | $114 |
| **D – Full Load (24h/day)** | 14.4 | $191 |

---

## Scaling Behavior and Cost Growth Analysis

When transaction volume doubles (e.g., **14.4 M → 28.8 M / month**), cost does **not** double linearly — but under sustained full-load, both **Control Plane (CP)** and **Aurora** are always active.

| Component | Behavior | Cost Growth |
|------------|-----------|-------------|
| **ALB** | Fixed hourly + minor LCU change | ~$20 → ~$22 |
| **DP Fargate (Base)** | Always-on task (1 vCPU + 2 GB) | ~$10.7 → ~$21.4 (if scaled to 2 tasks) |
| **CP Fargate** | Always-on under full load (0.25 vCPU + 0.5 GB) | ~$10.4 → ~$20.8 |
| **Aurora Compute** | 1 ACU → 2 ACUs 24h/day | ~$144 → ~$288 |
| **Aurora Storage** | Slight increase (logs, cache) | ~$2.3 → ~$3 |
| **Route 53 + CW** | Fixed | ~$3.5 → ~$3.5 |

**Estimated Monthly Total:** ≈ **$390–410**,  
still **below 2× linear cost ($382)** because ALB, storage, and monitoring are fixed.

> ⚙️ **Rule of Thumb:** When both **Aurora** and **CP** are always active, cost scales at roughly **+95–105%** per 100% increase in traffic.  
> ⚡ **Main drivers:** Aurora ACUs and CP task compute usage dominate total cost.

---

**← Back to [Architecture Overview](./README.md)**
