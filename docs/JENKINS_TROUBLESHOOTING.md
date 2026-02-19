# Jenkins & CI/CD Troubleshooting Guide
## Case Study: "git: command not found"

This guide documents the resolution for the common `git: command not found` error encountered in the Spring PetClinic Microservices pipeline.

---

### 1. Root Cause Analysis
The error typically occurs for one of three reasons:

1.  **Git is not installed**: The EC2 instance (build agent) does not have the Git package installed.
2.  **PATH Environment Variable**: Git is installed in a non-standard directory that is not included in the `$PATH` variable of the execution user (`ec2-user`).
3.  **Tooling Configuration**: In Jenkins, the "Global Tool Configuration" for Git might be pointing to a path that doesn't exist on this specific agent.

---

### 2. Immediate Troubleshooting Steps
To diagnose the environment, add these commands to your pipeline script right before the failing line:

```bash
whoami
echo $PATH
```

#### Manual Installation (Standard EC2 / Amazon Linux):
If Git is missing, run the following on your agent node:

```bash
sudo yum update -y
sudo yum install git -y
```

#### Jenkins Pipeline Resolution:
Ensure your path is correctly defined or use the Jenkins tool directive to force the environment to load the correct binary:

```groovy
pipeline {
    agent any
    stages {
        stage('Initialize') {
            steps {
                // This ensures Jenkins uses the configured Git installation
                script {
                    def gitPath = tool name: 'Default', type: 'git'
                    withEnv(["PATH+GIT=${gitPath}/bin"]) {
                        sh 'git --version'
                    }
                }
            }
        }
    }
}
```

---

### 3. DevSecOps Audit Perspective
Since we are working with microservices, ensuring the build environment is **immutable** is key.

#### Optimization Target: Dockerized Agents
Instead of installing Git manually on an EC2 instance, use a Dockerized Agent. This ensures the environment is identical every time and always contains the necessary binaries (JDK, Maven, Git, etc.).

---

### 4. Storage & Resource Issues
#### Case Study: "No space left on device" (Trivy Scan)
If Trivy fails while downloading vulnerability databases:
- **Symptom**: `write /tmp/...: no space left on device`.
- **Cause**: `/tmp` is often a small RAM-disk (`tmpfs`).
- **Resolution**: Redirect the Trivy cache and temporary directory to a larger physical data disk (e.g., `/mnt/data`).

```groovy
export TMPDIR=/mnt/data/trivy/tmp
trivy image --cache-dir /mnt/data/trivy/cache [IMAGE]
```

---
*Created on: 2026-02-18*
