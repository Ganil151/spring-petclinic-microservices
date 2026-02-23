# Terragrunt & Tiered Security Migration

## Overview
This document summarizes the "High-Rigor" migration of the Spring Petclinic infrastructure from standalone Terraform to **Terragrunt**, and the implementation of a **Tiered Security Model**.

## 1. The Terragrunt Refactor
We moved away from directory-based environment separation to a centralized Terragrunt orchestration.

### Key Changes:
- **Dependency Graph:** Implemented `dependency` blocks to replace hardcoded IDs. Resources now flow naturally (VPC -> SG -> EC2 -> RDS).
- **Environment Parity:** Created a `env.yaml` as the Single Source of Truth (SSOT). Changing a version or instance count in `env.yaml` cascades through the entire infrastructure.
- **Dry Configuration:** Eliminated repetitive provider and backend blocks using `generate` and `include` in the root `terragrunt.hcl`.

## 2. Tiered Security Model (The 4-Tier Defense)
We collapsed dozens of micro-security groups into a logical, identity-based tiered model.

| Tier | Purpose | Ingress Logic |
| :--- | :--- | :--- |
| **Management** | Bastion / Jump Box | Port 22 limited to authorized Admin IPs. |
| **Web** | Application Load Balancer | Ports 80/443 open to the public. |
| **Application** | Microservices & Tools | Ports 8080-9411 access ONLY from Web & Mgmt tiers. |
| **Data** | RDS / Storage | Ports 3306/5432 access ONLY from App & Mgmt tiers. |

### Industrial Rigor: SG Referencing
We moved away from CIDR-based rules for internal traffic. The Data Tier now says: *"I only trust traffic from source `sg-app`."* This prevents lateral movement if a non-app instance is launched in the VPC.

## 3. Network Segmentation (Private Immersion)
The core infrastructure has been moved to **Private Subnets**.
- **Public:** Only the Bastion and ALB exist in the public tier.
- **Private:** Jenkins, SonarQube, and Kubernetes Worker Nodes are fully submerged.
- **Egress:** Managed via NAT Gateways.
- **Connectivity:** Ansible now uses **SSH ProxyTunneling (ProxyCommand)** through the Bastion to reach private instances.

## 4. Modular Jenkins-as-Code (JCasC)
The Jenkins configuration was refactored into a modular engine.
- **JCasC (`jenkins.yaml`):** Automates the setup of the Kubernetes cloud and pod agents.
- **Modular Pipelines:** Split monolithic logic into `security-scan.groovy`, `deployment.groovy`, and `utils.groovy`.
- **Ephemeral Agents:** All builds now run in temporary Kubernetes pods rather than static worker instances.

## 5. Security Remediation
- **Credential Hygiene:** Purged all `.pem` files from the repository and established strict `.gitignore` patterns.
- **Least Privilege:** Replaced wide-open "God SGs" with the tiered model above.
- **RBAC:** Implemented granular Kubernetes RBAC for Spring Cloud services to discovery other pods safely.

---
**Status:** VALIDATED
**Environment:** `dev` (Functional)
**Next Step:** Propagate to `staging` and `prod` overlays.
