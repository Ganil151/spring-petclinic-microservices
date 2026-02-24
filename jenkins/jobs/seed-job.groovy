// Seed Job for Spring Petclinic Microservices
// This Job DSL script creates and configures all Jenkins jobs programmatically

// Main CI/CD Pipeline
pipelineJob('spring-petclinic-cicd') {
    description('Main CI/CD Pipeline for Spring Petclinic Microservices')
    definition {
        cps {
            scriptPath('Jenkinsfile')
            lightweight()
        }
    }
    
    properties {
        parameters {
            booleanParam('RUN_SECURITY_SCAN', true, 'Run security scans')
            stringParam('BRANCH', 'main', 'Branch to build')
        }
    }
    
    triggers {
        githubPush()
        cron('H 2 * * *') // Daily build at 2 AM
    }
}

// Security Scan Job
pipelineJob('security-scan') {
    description('Security Scanning Pipeline')
    definition {
        cps {
            scriptPath('jenkins/pipelines/security-scan-pipeline.groovy')
            lightweight()
        }
    }
    
    triggers {
        cron('H 3 * * *') // Daily at 3 AM
    }
}

// Deployment Job
pipelineJob('deploy-to-dev') {
    description('Deploy to Development Environment')
    definition {
        cps {
            scriptPath('jenkins/pipelines/deployment-pipeline.groovy')
            lightweight()
        }
    }
}

// Build Job
freestyleJob('build-petclinic') {
    description('Build and Package Spring Petclinic')
    
    scm {
        git {
            remote {
                url('https://github.com/spring-projects/spring-petclinic-microservices.git')
            }
            branch('*/main')
        }
    }
    
    steps {
        maven {
            mavenInstallation('Maven 3')
            goals('clean package -DskipTests')
        }
    }
}

logger.info("Seed job completed - All jobs created successfully")
