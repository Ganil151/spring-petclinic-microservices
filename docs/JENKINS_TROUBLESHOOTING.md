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

### 5. SonarQube Analysis: "Expected URL scheme 'http' or 'https'"
- **Symptom**: `Unable to execute SonarScanner analysis: Fail to get bootstrap index from server: Expected URL scheme 'http' or 'https' but no colon was found`.
- **Cause**: The `SONAR_URL` parameter was missing from the Jenkins pipeline parameters, leading to an empty `-Dsonar.host.url` value.
- **Resolution**:
    1.  Add `SONAR_URL` to the `parameters` block in the `Jenkinsfile`.
    2.  Use `${params.SONAR_URL}` in the `sh` command.
    3.  Ensure the default value (e.g., `http://10.0.1.14:9000`) is valid.

---

### 6. Spring Boot Admin Server CrashLoopBackOff: "ClassNotFoundException: WebClientAutoConfiguration"
- **Symptom**: The `admin-server` pod is in `CrashLoopBackOff` state. Pod logs (`kubectl logs -n petclinic admin-server-...`) show: `java.lang.IllegalArgumentException: Could not find class [org.springframework.boot.autoconfigure.web.reactive.function.client.WebClientAutoConfiguration]`.
- **Cause**: The project was recently updated to Spring Boot 4 (`4.0.1`), but the `spring-petclinic-admin-server` module had a hardcoded `spring-boot-admin.version` set to an older version (`3.4.1`). With structural changes inside Spring Boot 4, the `WebClientAutoConfiguration` class moved, causing the old Admin server dependency to fail on startup.
- **Resolution**: Edit `spring-petclinic-admin-server/pom.xml` to update `<spring-boot-admin.version>` to `4.0.0` to ensure compatibility with Spring Boot 4.

---

### 7. Maven "mvn: command not found" & "./mvnw compile error: release version 21 not supported"
- **Symptom**: Running `mvn clean package` fails with `mvn: command not found`. Running `./mvnw clean package` fails with `Fatal error compiling: error: release version 21 not supported`. The `javac` command might also be missing from the path.
- **Cause**: Maven is not installed globally on the environment, and the local Java installation (e.g., OpenJDK 25 without `javac` support for release 21, or missing JDK tools) cannot complete the build.
- **Resolution**: 
    1. Always use the Maven wrapper (`./mvnw`) to ensure independent execution.
    2. If the local environment lacks the correct JDK to build the project, rely on the Jenkins pipeline's Dockerized agents or explicitly install a complete JDK 21+ (`sudo yum install java-21-amazon-corretto-devel -y`) before building.

---
*Created on: 2026-02-18*
*Updated on: 2026-02-21*
