# Java 21 Migration Guide - Spring PetClinic Microservices

## Overview

This guide provides step-by-step instructions to migrate the Spring PetClinic Microservices from Java 17 to Java 21.

---

## Phase 1: Prerequisites

### Step 1.1: Install Java 21

```bash
# Amazon Corretto 21 (Recommended for AWS)
wget https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.tar.gz
tar -xzf amazon-corretto-21-x64-linux-jdk.tar.gz
sudo mv amazon-corretto-21.* /opt/java21

# Set JAVA_HOME
export JAVA_HOME=/opt/java21
export PATH=$JAVA_HOME/bin:$PATH

# Verify installation
java -version
```

**Expected Output:**

```
openjdk version "21.0.x" 2024-xx-xx LTS
OpenJDK Runtime Environment Corretto-21.0.x (build 21.0.x+xx-LTS)
```

### Step 1.2: Verify Maven Compatibility

```bash 
# Maven 3.9+ required for Java 21
mvn -version
```

---

## Phase 2: Update Project Configuration

### Step 2.1: Update Root POM

```bash
# Already completed - verify the change
grep -A 1 "<java.version>" pom.xml
```

**Expected Output:**

```xml
<java.version>21</java.version>
```

### Step 2.2: Update All Module POMs

```bash
# Verify all modules inherit Java 21 from parent
for module in spring-petclinic-*/pom.xml; do
  echo "Checking $module"
  grep -A 5 "<parent>" "$module" | grep -A 1 "spring-petclinic-microservices"
done
```

### Step 2.3: Update Docker Base Images

```bash
# Update Dockerfile in docker/ directory
cat > docker/Dockerfile << 'EOF'
FROM eclipse-temurin:21-jre-alpine
ARG ARTIFACT_NAME
ARG EXPOSED_PORT
EXPOSE ${EXPOSED_PORT}
ADD ${ARTIFACT_NAME}.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
EOF
```

### Step 2.4: Update Maven Compiler Plugin (if needed)

```bash
# Check if maven-compiler-plugin is explicitly configured
find . -name "pom.xml" -exec grep -l "maven-compiler-plugin" {} \;

# If found, ensure version 3.11.0+
# Add to pom.xml if not present:
cat >> pom.xml << 'EOF'
<build>
  <pluginManagement>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.11.0</version>
        <configuration>
          <release>21</release>
        </configuration>
      </plugin>
    </plugins>
  </pluginManagement>
</build>
EOF
```

---

## Phase 3: Build and Test

### Step 3.1: Clean Build

```bash
# Clean all previous builds
./mvnw clean

# Build with Java 21
./mvnw clean install -DskipTests
```

**Expected Output:**

```
[INFO] BUILD SUCCESS
[INFO] Total time: 2:30 min
```

### Step 3.2: Run Tests

```bash
# Run all tests
./mvnw test

# Run tests for specific module
./mvnw test -pl spring-petclinic-customers-service
```

### Step 3.3: Verify Java Version in Build

```bash
# Check compiled class version
javap -v spring-petclinic-customers-service/target/classes/org/springframework/samples/petclinic/customers/CustomersServiceApplication.class | grep "major version"
```

**Expected Output:**

```
major version: 65  # Java 21
```

---

## Phase 4: Update Container Images

### Step 4.1: Rebuild Docker Images

```bash
# Build with Java 21 base image
./mvnw clean install -P buildDocker

# Verify Java version in container
docker run --rm springcommunity/spring-petclinic-api-gateway java -version
```

**Expected Output:**

```
openjdk version "21.0.x"
```

### Step 4.2: Update Docker Compose (if needed)

```bash
# Verify docker-compose.yml uses latest images
grep "image:" docker-compose.yml
```

---

## Phase 5: Local Testing

### Step 5.1: Start Services Locally

```bash
# Option 1: Docker Compose
docker compose down
docker compose up --build

# Option 2: Local Maven
./scripts/run_all.sh
```

### Step 5.2: Verify Application Health

```bash
# Wait for services to start
sleep 60

# Check API Gateway
curl http://localhost:8080/actuator/health

# Check Discovery Server
curl http://localhost:8761/actuator/health
```

**Expected Output:**

```json
{ "status": "UP" }
```

### Step 5.3: Run Integration Tests

```bash
# Test all endpoints
curl http://localhost:8080/api/customer/owners
curl http://localhost:8080/api/vet/vets
curl http://localhost:8080/api/visit/owners/1/pets/1/visits
```

---

## Phase 6: CI/CD Updates

### Step 6.1: Update GitHub Actions

```bash
# Edit .github/workflows/maven-build.yml
cat > .github/workflows/maven-build.yml << 'EOF'
name: Maven Build

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up JDK 21
      uses: actions/setup-java@v4
      with:
        java-version: '21'
        distribution: 'corretto'
        cache: maven

    - name: Build with Maven
      run: ./mvnw clean install -P buildDocker

    - name: Run tests
      run: ./mvnw test
EOF
```

### Step 6.2: Update DevContainer Configuration

```bash
# Edit .devcontainer/devcontainer.json
cat > .devcontainer/devcontainer.json << 'EOF'
{
  "name": "Spring PetClinic Microservices",
  "image": "mcr.microsoft.com/devcontainers/java:21",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "vscjava.vscode-java-pack",
        "vmware.vscode-spring-boot"
      ]
    }
  }
}
EOF
```

---

## Phase 7: AWS Deployment Updates

### Step 7.1: Update EKS Deployment Manifests

```bash
# Update container image tags in k8s manifests
find k8s/ -name "*.yaml" -type f -exec sed -i 's/eclipse-temurin:17/eclipse-temurin:21/g' {} \;
```

### Step 7.2: Update ECR Image Tags

```bash
# Rebuild and push with Java 21
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REGION=us-west-2

# Build with new Java version
./mvnw clean install -P buildDocker \
  -Ddocker.image.prefix=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/petclinic

# Tag images
docker tag ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/petclinic/api-gateway:latest \
  ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/petclinic/api-gateway:java21

# Push to ECR
aws ecr get-login-password --region ${REGION} | \
  docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/petclinic/api-gateway:java21
```

---

## Phase 8: Verification Checklist

- [ ] Java 21 installed and JAVA_HOME set
- [ ] Root pom.xml updated to Java 21
- [ ] All modules build successfully
- [ ] All tests pass
- [ ] Docker images use Java 21 base
- [ ] Local deployment works (Docker Compose)
- [ ] Local deployment works (Maven)
- [ ] Health checks pass for all services
- [ ] Integration tests pass
- [ ] CI/CD pipeline updated
- [ ] Container images pushed to registry
- [ ] Documentation updated

---

## Troubleshooting

### Issue 1: Compilation Errors

```bash
# Clear Maven cache
rm -rf ~/.m2/repository

# Rebuild
./mvnw clean install -U
```

### Issue 2: Docker Build Fails

```bash
# Check Docker daemon
docker info

# Rebuild with verbose output
./mvnw clean install -P buildDocker -X
```

### Issue 3: Tests Fail

```bash
# Run specific test with debug
./mvnw test -Dtest=ApiGatewayControllerTest -X

# Check test logs
cat spring-petclinic-*/target/surefire-reports/*.txt
```

### Issue 4: Container Won't Start

```bash
# Check container logs
docker logs <container-id>

# Verify Java version in container
docker run --rm --entrypoint java springcommunity/spring-petclinic-api-gateway -version
```

---

## Java 21 Features to Leverage (Optional)

### Virtual Threads (Project Loom)

```java
// Enable virtual threads in application.yml
spring:
  threads:
    virtual:
      enabled: true
```

### Pattern Matching Enhancements

```java
// Use pattern matching for instanceof
if (pet instanceof Dog dog) {
    dog.bark();
}
```

### Record Patterns

```java
// Deconstruct records in switch
switch (owner) {
    case Owner(String firstName, String lastName, _) ->
        System.out.println(firstName + " " + lastName);
}
```

---

## Rollback Plan

If issues arise, rollback to Java 17:

```bash
# Revert pom.xml
git checkout HEAD -- pom.xml

# Rebuild with Java 17
export JAVA_HOME=/opt/java17
./mvnw clean install -P buildDocker

# Redeploy previous images
kubectl set image deployment/api-gateway api-gateway=springcommunity/spring-petclinic-api-gateway:java17
```

---

## Additional Resources

- [Java 21 Release Notes](https://openjdk.org/projects/jdk/21/)
- [Spring Boot 4.0 Java 21 Support](https://spring.io/blog/2024/01/18/spring-boot-4-0-0-m1-available-now)
- [AWS Corretto 21 Documentation](https://docs.aws.amazon.com/corretto/latest/corretto-21-ug/)
