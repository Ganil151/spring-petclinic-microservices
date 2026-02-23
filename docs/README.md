# Documentation Directory

This directory contains key documentation, runbooks, references, and diagrams for the Spring PetClinic Microservices project.

## 🛡️ High-Rigor Infrastructure (Latest Migration)
* [ARCHITECTURE.md](./ARCHITECTURE.md) - **Master Blueprint**: Detailed tiered design, microservice mesh, and automation stack.
* [TERRAGRUNT_MIGRATION.md](./TERRAGRUNT_MIGRATION.md) - Details the 4-tier security group refactor and Terragrunt SSOT implementation.
* [SECURITY_COMPLIANCE.md](./SECURITY_COMPLIANCE.md) - Our "Security-First" standards, including the "Bubble" strategy and identity-based access.

## 📄 Core Documentation
* [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - High-level quick reference for Terraform commands, Ansible playbooks, Helm chart deployments, and environment sizing.
* [REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md) - Historical summary of structural refactorings.
* [JAVA21_MIGRATION.md](./JAVA21_MIGRATION.md) - Details the ongoing Spring Boot 4 and Java 21 migration checklist.

## 🚀 Deployment & Operations
* [RUNBOOK_AWS_DEPLOY.md](./RUNBOOK_AWS_DEPLOY.md) - The primary step-by-step master runbook detailing end-to-end AWS deployment of the environment.
* [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) - A granular chronological checklist matching the AWS Deploy runbook.
* [JENKINS_TROUBLESHOOTING.md](./JENKINS_TROUBLESHOOTING.md) - Real-world case studies and solutions to pipeline issues (e.g. Git pathing, Trivy storage, Spring Admin versions, Maven/JDK fixes).

## ⚙️ Configuration & Reference
* [.bashrc](./.bashrc) - Custom alias and function profile to be auto-applied to EC2 bootstrap scripts (Jenkins, Worker, SonarQube). Provides fast CLI utilities.
* [PORT_SUMMARY.md](./PORT_SUMMARY.md) - A summary overview of the listening ports mapped for various microservices and tools.
* [PORT_CONFIGURATION.md](./PORT_CONFIGURATION.md) - Detailed breakdown of EC2 Security Group configurations, internal networking rules, and target ports.

## 🖼️ Media & Diagrams
* [microservices-architecture-diagram.jpg](./microservices-architecture-diagram.jpg) - Visual layout of the architecture.
* [application-screenshot.png](./application-screenshot.png) - A snapshot of the running application.
* [grafana-custom-metrics-dashboard.png](./grafana-custom-metrics-dashboard.png) - A sample custom Grafana monitoring metric dashboard.
* [spring-ai.png](./spring-ai.png) - Spring AI demonstration screenshot.

