# 💰 Infrastructure Cost Management

In this project, we utilize **Infracost** to provide real-time cost estimates for our AWS infrastructure before any resources are actually provisioned. This is a critical component of our **FinOps** (Financial Operations) strategy.

## 🛠️ Tooling: Infracost
Infracost is installed automatically on the **Bastion Host** via Ansible. It scans your Terraform/Terragrunt code and generates a breakdown of costs based on the AWS Price List API.

## 🚀 How to Run Cost Estimates

### 1. Manual Check (from Bastion)
Connect to your bastion host and run the following command within your environment directory:

```bash
cd /opt/spring-petclinic/terraform/live/dev
infracost breakdown --path .
```

### 2. Compare Changes (Diff)
To see how much your monthly bill will change after a planned modification:

```bash
infracost diff --path .
```

## 🤖 CI/CD Integration (Jenkins)
Our Jenkins pipeline is configured to automatically run Infracost during the `Build` phase for any Infrastructure changes. 

### Jenkinsfile Snippet
```groovy
stage('Cost Estimation') {
    steps {
        sh "infracost breakdown --path terraform/live/dev --format json --out-file report.json"
        // Optionally post to a Slack channel or Dashboard
    }
}
```

## 📈 Cost Optimization Strategies
To maintain "Industrial Rigor" and keep costs low:
1.  **Spot Instances**: Used for non-critical Kubernetes worker nodes.
2.  **GP3 Storage**: We use `gp3` instead of `gp2` for EBS volumes to save ~20% on storage costs while maintaining better latency.
3.  **Instance Sizing**: We use `t3.micro` for Bastion and `t3.medium` for Jenkins/SonarQube as the "Baseline" (vCPU Credit model) to minimize idle costs.

## ⚠️ Important Note
You must obtain an Infracost API key (free for individuals) and set it on the Bastion host or Jenkins environment:
```bash
infracost auth login
# OR
export INFRACOST_API_KEY=your_key_here
```
