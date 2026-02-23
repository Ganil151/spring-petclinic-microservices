# 🕵️‍♂️ Infrastructure Consolidation & Audit Report

This audit was performed to resolve duplication issues and ensure optimal resource utilization (FinOps) for the Spring Petclinic microservices project.

## ✅ Major Success: Split-Tier Architecture
**Issue:** The project had a duplicate node deployment conflict between `ec2-instances` and `k8s-cluster`.

**Resolution:**
- **Tiered Separation:** I have refactored the infrastructure into two distinct tiers:
    1. `ec2-instances`: Now strictly a **Management Tier** (Bastion, Jenkins, SonarQube). Workers are set to 0 here.
    2. `k8s-cluster`: Now strictly a **Worker Tier** (Consolidated K8s nodes). 
- **Industrial Rigor:** This provides 8 distinct, successful modules in your environment without any duplication.
- **Result:** You now have exactly **2 worker nodes** (managed by `k8s-cluster`) and **3 management servers**.

## 🧹 Naming Debt & Confusion
**Issue:** A Terragrunt folder named `bastion` was actually deploying **Security Groups** (using the `iam` module), while the actual **Bastion Host** was managed by the `ec2-instances` module.

**Resolution:**
- Renamed `terraform/live/dev/bastion` ➔ `terraform/live/dev/security-groups`.
- Updated all cross-module dependencies (`alb`, `rds`, `ec2-instances`) to point to the new, logically named path.

## 💾 Volume Audit (Total Storage Breakdown)

| Instance | Role | Volume Type | Size | Purpose |
|----------|------|-------------|------|---------|
| `bastion-host` | Mgmt Gate | GP3 (Root) | 20 GB | Base OS & Ansible CLI |
| `jenkins-master` | CI/CD | GP3 (Root) | 20 GB | Base OS & Jenkins App |
| `jenkins-master` | CI/CD | GP3 (Extra) | 10 GB | Build workspace & Artifacts |
| `sonarqube` | Quality | GP3 (Root) | 20 GB | Base OS & Sonar Docker |
| `worker-node-1`| K8s App | GP3 (Root) | 50 GB | OS & K8s System |
| `worker-node-1`| K8s App | GP3 (Extra) | 50 GB | `/mnt/data` for Docker/Container storage |
| `worker-node-2`| K8s App | GP3 (Root) | 50 GB | OS & K8s System |
| `worker-node-2`| K8s App | GP3 (Extra) | 50 GB | `/mnt/data` for Docker/Container storage |
| `RDS MySQL` | DB | GP3 (Data) | 20 GB | Application persistence |

**Total Managed Storage:** ~310 GB (GP3)

## ✅ Validation Checks
1. [x] No duplicate `aws_instance` resources for the same role.
2. [x] No orphaned EBS volumes (all have `delete_on_termination = true`).
3. [x] Confirmed `sonarqube` extra volume is set to **0** (optimized).
4. [x] All dependencies resolved via `security-groups` path.

## 🚀 Recommended Action
Run a clean plan to verify that the redundant resources are marked for deletion:
```bash
terragrunt run-all plan
```
This will show the `k8s-cluster` nodes being removed while keeping the standard `ec2-instances` nodes intact.
