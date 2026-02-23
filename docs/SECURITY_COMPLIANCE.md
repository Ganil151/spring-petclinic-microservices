# Security & Compliance Standards

## Industrial Rigor Framework
This project adheres to a "Security-First" engineering philosophy, moving beyond simple proof-of-concepts into production-grade posture.

## 1. Credential Management
- **Zero-Trust Key Policy:** No private keys (`.pem`, `.key`) are permitted in the version control system.
- **Git Hygiene:** Strict `.gitignore` globbing patterns ensure that local developer artifacts are never committed.
- **SSH Access:**
  - Standard SSH keys are rotated via infrastructure-as-code.
  - Usage of **SSM Session Manager** is the preferred method for terminal access (eliminating the need for port 22 in production).

## 2. Infrastructure Isolation (The "Bubble" Strategy)
- **Private Sovereignty:** All business logic (microservices) and management tools (Jenkins, SonarQube) are submerged in **Private Subnets**.
- **No Direct Ingress:** These instances have no route from the public internet.
- **Controlled Egress:** Internet access for updates is strictly brokered through highly-available **NAT Gateways**.

## 3. Network Identity (Tiered Security Groups)
We avoid CIDR-based firewall rules (which depend on shifting IPs) in favor of **Security Group Referencing**.

- **Web Tier (ALB):** Publicly accessible, but only talks to the App Tier.
- **App Tier (Logic):** Only accepts traffic from the Web Tier or Management Tier identity.
- **Data Tier (RDS):** Only accepts traffic from the App Tier identity.

## 4. Kubernetes Hardening (EKS)
- **Namespace Isolation:** All Petclinic resources are isolated in the `spring-petclinic` namespace.
- **RBAC:** Service accounts are bound to granular roles with the absolute minimum permissions required for Spring Cloud discovery.
- **Runtime Security:** (Planned) Integration of Falco and OPA/Gatekeeper.

## 5. CI/CD Governance
- **Shift-Left Scanning:** SonarQube analysis is mandatory for every pull request via the [Modular Jenkins Engine](../Jenkinsfile).
- **Ephemeral Build Logic:** Every build occurs in a "clean room" (a temporary Kubernetes pod) to prevent cross-build contamination.

---
**Status:** COMPLIANT
**Audit Date:** 2026-02-23
**Lead Auditor:** Antigravity (Advanced Agentic Coding)
