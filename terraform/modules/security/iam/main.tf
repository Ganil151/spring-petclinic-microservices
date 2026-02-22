# =============================================================================
# Security Groups for Spring Petclinic Microservices
# =============================================================================

# -----------------------------------------------------------------------------
# API Gateway Security Group - Public facing entry point
# -----------------------------------------------------------------------------
resource "aws_security_group" "api_gateway" {
  name        = "${var.project_name}-${var.environment}-api-gateway-sg"
  description = "Security group for API Gateway"
  vpc_id      = var.vpc_id

  # HTTP/HTTPS from public
  ingress {
    description = "HTTP from public"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.public_cidr_blocks
  }

  # All outbound traffic allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-gateway-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "api-gateway"
  }
}

# -----------------------------------------------------------------------------
# Admin Server Security Group - Spring Boot Admin
# -----------------------------------------------------------------------------
resource "aws_security_group" "admin_server" {
  name        = "${var.project_name}-${var.environment}-admin-server-sg"
  description = "Security group for Admin Server"
  vpc_id      = var.vpc_id

  # HTTP from admin CIDR only
  ingress {
    description = "HTTP from admin networks"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # SSH from bastion (if configured)
  dynamic "ingress" {
    for_each = var.bastion_security_group_id != null ? [1] : []
    content {
      description     = "SSH from bastion"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [var.bastion_security_group_id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-admin-server-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "admin-server"
  }
}

# -----------------------------------------------------------------------------
# Config Server Security Group - Internal only
# -----------------------------------------------------------------------------
resource "aws_security_group" "config_server" {
  name        = "${var.project_name}-${var.environment}-config-server-sg"
  description = "Security group for Config Server"
  vpc_id      = var.vpc_id

  # Config server port - internal only
  ingress {
    description = "Config server port from VPC"
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-config-server-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "config-server"
  }
}

# -----------------------------------------------------------------------------
# Discovery Server Security Group - Eureka
# -----------------------------------------------------------------------------
resource "aws_security_group" "discovery_server" {
  name        = "${var.project_name}-${var.environment}-discovery-server-sg"
  description = "Security group for Discovery Server (Eureka)"
  vpc_id      = var.vpc_id

  # Eureka port - internal only
  ingress {
    description = "Eureka port from VPC"
    from_port   = 8761
    to_port     = 8761
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-discovery-server-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "discovery-server"
  }
}

# -----------------------------------------------------------------------------
# Microservices Security Group - Customers, Visits, Vets, GenAI
# -----------------------------------------------------------------------------
resource "aws_security_group" "microservices" {
  name        = "${var.project_name}-${var.environment}-microservices-sg"
  description = "Security group for backend microservices"
  vpc_id      = var.vpc_id

  # Customers Service
  ingress {
    description = "Customers service from VPC"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  # Visits Service
  ingress {
    description = "Visits service from VPC"
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  # Vets Service
  ingress {
    description = "Vets service from VPC"
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  # GenAI Service
  ingress {
    description = "GenAI service from VPC"
    from_port   = 8084
    to_port     = 8084
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  # SSH from bastion (if configured)
  dynamic "ingress" {
    for_each = var.bastion_security_group_id != null ? [1] : []
    content {
      description     = "SSH from bastion"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [var.bastion_security_group_id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-microservices-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "microservices"
  }
}

# -----------------------------------------------------------------------------
# Database Security Group - RDS
# -----------------------------------------------------------------------------
resource "aws_security_group" "database" {
  name        = "${var.project_name}-${var.environment}-database-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  # MySQL
  ingress {
    description = "MySQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.db_cidr_blocks
  }

  # PostgreSQL
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.db_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-database-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "database"
  }
}

# -----------------------------------------------------------------------------
# Zipkin Tracing Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "zipkin" {
  name        = "${var.project_name}-${var.environment}-zipkin-sg"
  description = "Security group for Zipkin tracing"
  vpc_id      = var.vpc_id
  count       = var.enable_zipkin ? 1 : 0

  # Zipkin UI port - admin access only
  ingress {
    description = "Zipkin UI from admin networks"
    from_port   = 9411
    to_port     = 9411
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-zipkin-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "zipkin"
  }
}

# -----------------------------------------------------------------------------
# Grafana Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "grafana" {
  name        = "${var.project_name}-${var.environment}-grafana-sg"
  description = "Security group for Grafana"
  vpc_id      = var.vpc_id
  count       = var.enable_grafana ? 1 : 0

  # Grafana UI port - admin access only
  ingress {
    description = "Grafana UI from admin networks"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-grafana-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "grafana"
  }
}

# -----------------------------------------------------------------------------
# Prometheus Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "prometheus" {
  name        = "${var.project_name}-${var.environment}-prometheus-sg"
  description = "Security group for Prometheus"
  vpc_id      = var.vpc_id
  count       = var.enable_prometheus ? 1 : 0

  # Prometheus port - admin access only
  ingress {
    description = "Prometheus UI from admin networks"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-prometheus-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "prometheus"
  }
}

# -----------------------------------------------------------------------------
# ALB Security Group - For load balancer
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP
  ingress {
    description = "HTTP from public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.public_cidr_blocks
  }

  # HTTPS
  ingress {
    description = "HTTPS from public"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.public_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "alb"
  }
}

# -----------------------------------------------------------------------------
# Kubernetes Node Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "k8s_nodes" {
  name        = "${var.project_name}-${var.environment}-k8s-nodes-sg"
  description = "Security group for Kubernetes nodes"
  vpc_id      = var.vpc_id

  # Kubernetes API server
  ingress {
    description = "Kubernetes API from VPC"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  # Node ports range
  ingress {
    description = "Node ports from VPC"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  # SSH from bastion (if configured)
  dynamic "ingress" {
    for_each = var.bastion_security_group_id != null ? [1] : []
    content {
      description     = "SSH from bastion"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [var.bastion_security_group_id]
    }
  }

  # Allow traffic from ALB
  dynamic "ingress" {
    for_each = var.alb_security_group_id != null ? [1] : []
    content {
      description     = "HTTP from ALB"
      from_port       = 8080
      to_port         = 8080
      protocol        = "tcp"
      security_groups = [var.alb_security_group_id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-k8s-nodes-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "k8s-nodes"
  }
}

# -----------------------------------------------------------------------------
# Bastion Host Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for Bastion Host"
  vpc_id      = var.vpc_id

  # SSH from public (restrict in production!)
  ingress {
    description = "SSH from public"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.public_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "bastion"
  }
}
