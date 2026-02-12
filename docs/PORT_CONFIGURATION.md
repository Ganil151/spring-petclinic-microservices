# Port Configuration Guide

## Overview
This document describes all configured network ports for the Spring PetClinic Microservices infrastructure across all environments (dev, staging, prod).

## Port Categories

### 🔐 Infrastructure Access Ports

| Port | Service | Protocol | Description | Environment Access |
|------|---------|----------|-------------|-------------------|
| 22 | SSH | TCP | Secure Shell access to EC2 instances | Dev/Staging: Public<br>Prod: Internal only |
| 80 | HTTP | TCP | Unencrypted web traffic (redirect to HTTPS) | All environments |
| 443 | HTTPS | TCP | Encrypted web traffic (SSL/TLS) | All environments |

### 🗄️ Database Ports

| Port | Service | Protocol | Description | Environment Access |
|------|---------|----------|-------------|-------------------|
| 3306 | MySQL/RDS | TCP | MySQL database connections | Dev/Staging: VPC<br>Prod: Private subnet only |

### 🛠️ CI/CD Tools

| Port | Service | Protocol | Description | Environment Access |
|------|---------|----------|-------------|-------------------|
| 8080 | Jenkins | TCP | Jenkins web interface and API | All environments |
| 9000 | SonarQube | TCP | SonarQube code quality dashboard | All environments |

### 🎯 Spring PetClinic Core Services

| Port | Service | Protocol | Description |
|------|---------|----------|-------------|
| 8080 | API Gateway | TCP | Spring Cloud Gateway - main entry point |
| 8761 | Discovery Server | TCP | Eureka service registry |
| 8888 | Config Server | TCP | Centralized configuration management |
| 9090 | Admin Server | TCP | Spring Boot Admin monitoring interface |

### 🐾 PetClinic Microservices

| Port | Service | Protocol | Description |
|------|---------|----------|-------------|
| 8081 | Customers Service | TCP | Customer management microservice |
| 8082 | Vets Service | TCP | Veterinarian management microservice |
| 8083 | Visits Service | TCP | Pet visit tracking microservice |

### 📊 Monitoring & Observability

| Port | Service | Protocol | Description |
|------|---------|----------|-------------|
| 9091 | Prometheus | TCP | Metrics collection and monitoring |
| 3000 | Grafana | TCP | Metrics visualization dashboards |
| 9411 | Zipkin | TCP | Distributed tracing UI |

### 🔧 Additional Service Ports

| Port Range | Service | Protocol | Description |
|------------|---------|----------|-------------|
| 8000-8999 | Custom Applications | TCP | Reserved for custom microservices |
| 9000-9999 | Actuator Endpoints | TCP | Spring Boot Actuator health/metrics endpoints |

## Security Configuration by Environment

### Development Environment
- **CIDR Blocks**: `0.0.0.0/0` (open for testing)
- **Public Access**: Enabled for Jenkins, SonarQube, and application services
- **SSH Access**: Allowed from anywhere
- **Use Case**: Rapid development and testing

### Staging Environment
- **CIDR Blocks**: `0.0.0.0/0` (controlled access)
- **Public Access**: Enabled for testing purposes
- **SSH Access**: Allowed from anywhere
- **Use Case**: Pre-production validation and UAT

### Production Environment
- **CIDR Blocks**: `10.0.0.0/8` (internal network only)
- **Public Access**: Restricted to ALB/Load Balancer only
- **SSH Access**: VPN or bastion host required
- **Database**: Private subnet access only
- **Monitoring Tools**: Internal access only
- **Use Case**: Production workloads with enhanced security

## Port Configuration in Terraform

### Location
Ports are configured in each environment's `terraform.tfvars` file under the `ingress_rules` variable.

### Structure
```hcl
ingress_rules = {
  service_name = {
    from_port   = <port_number>
    to_port     = <port_number>
    protocol    = "tcp"
    description = "Service description"
  }
}
```

### Example
```hcl
ingress_rules = {
  ssh = {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "SSH access"
  }
  jenkins = {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    description = "Jenkins web interface"
  }
}
```

## Adding New Ports

### Step 1: Update terraform.tfvars
Add the new rule to the `ingress_rules` map in the environment's `terraform.tfvars`:

```hcl
# In environments/dev/terraform.tfvars
ingress_rules = {
  # ... existing rules ...
  
  new_service = {
    from_port   = 8095
    to_port     = 8095
    protocol    = "tcp"
    description = "New microservice"
  }
}
```

### Step 2: Apply Changes
```bash
cd environments/dev
terraform plan
terraform apply
```

### Step 3: Update Documentation
Add the new port to this document and any relevant README files.

## Port Conflicts to Avoid

### Known Conflicts
- **8080**: Shared by Jenkins and API Gateway (separate instances)
- **9000**: Shared by SonarQube and Actuator range (separate instances)
- **9090**: Shared by Admin Server and Prometheus in some setups

### Resolution
- Use different EC2 instances or containers for conflicting services
- Consider using port ranges or dynamic ports
- Use reverse proxy (Nginx/ALB) to route traffic

## Security Best Practices

### ✅ DO
- Use HTTPS (443) for all public-facing services
- Restrict SSH (22) to bastion hosts or VPN in production
- Keep database ports (3306) in private subnets
- Use security groups to limit access by source IP/CIDR
- Enable VPC Flow Logs for traffic monitoring
- Use AWS Systems Manager Session Manager instead of SSH when possible

### ❌ DON'T
- Expose database ports to the public internet
- Use `0.0.0.0/0` for production environments
- Open wide port ranges unless necessary
- Allow SSH from anywhere in production
- Expose monitoring tools (Grafana, Prometheus) publicly

## Health Check Endpoints

Most services expose health checks on their main port:
- **Spring Boot Services**: `http://service:port/actuator/health`
- **Jenkins**: `http://jenkins:8080/login`
- **SonarQube**: `http://sonarqube:9000/api/system/status`
- **Eureka**: `http://eureka:8761/actuator/health`

## Troubleshooting

### Port Connection Issues

1. **Check Security Group Rules**
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

2. **Verify Service is Running**
   ```bash
   sudo netstat -tlnp | grep <port>
   # or
   sudo ss -tlnp | grep <port>
   ```

3. **Test Port Connectivity**
   ```bash
   telnet <host> <port>
   # or
   nc -zv <host> <port>
   ```

4. **Check VPC Flow Logs**
   - Navigate to VPC → Flow Logs in AWS Console
   - Filter by destination port
   - Check for REJECT entries

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Timeout on port | Security group blocked | Add ingress rule |
| Connection refused | Service not running | Start the service |
| Cannot bind to port | Port already in use | Use different port or stop conflicting service |
| Intermittent connectivity | Network ACL issue | Check subnet NACL rules |

## References

- [Spring Cloud Gateway Docs](https://spring.io/projects/spring-cloud-gateway)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Netflix Eureka](https://github.com/Netflix/eureka)
- [AWS Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [SonarQube Documentation](https://docs.sonarqube.org/)

## Quick Reference Matrix

| Service | Dev Port | Staging Port | Prod Port | Public Access (Prod) |
|---------|----------|--------------|-----------|----------------------|
| SSH | 22 | 22 | 22 | ❌ No (VPN only) |
| HTTP | 80 | 80 | 80 | ✅ Yes (via ALB) |
| HTTPS | 443 | 443 | 443 | ✅ Yes (via ALB) |
| Jenkins | 8080 | 8080 | 8080 | ❌ No (internal) |
| SonarQube | 9000 | 9000 | 9000 | ❌ No (internal) |
| MySQL | 3306 | 3306 | 3306 | ❌ No (private subnet) |
| API Gateway | 8080 | 8080 | 8080 | ✅ Yes (via ALB) |
| Eureka | 8761 | 8761 | 8761 | ❌ No (internal) |
| Config Server | 8888 | 8888 | 8888 | ❌ No (internal) |
| Grafana | 3000 | 3000 | 3000 | ❌ No (internal) |
| Prometheus | 9091 | 9091 | 9091 | ❌ No (internal) |

---

**Last Updated**: 2026-02-12  
**Version**: 1.0  
**Maintained By**: DevOps Team
