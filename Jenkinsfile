pipeline{
    agent{
        label params.NODE_LABEL
    }
    environment {
      AWS_REGION = 'us-east-1'
      INSTANCE_TYPE 't3.small'
      KEY_NAME = 'sis_keys'
      SECURITY_GROUP_ID = 'sg-05ca6243c057b95fe'
      SUBNET_ID = 'subnet-07d92cb4846fd94a3'
      DOCKER_IMAGE = 'ganil151/spring-petclinic-microservice:latest'
      INSTANCE_ID = ''
      PUBLIC_ID = ''
    }
    parameters {
        string(
            name: 'NODE_LABEL',
            defaultValue: 'worker-node-1',
            description: 'Label of the Jenkins worker node to run this pipeline'
        )
    }
    stages{
        stage('Provision EC2 Instance'){
            steps {
                script {
                   def instanceInfo = sh(script: """
                        aws ec2 run-instances \
                            --image-id ami-00ca32bbc84273381 \\ 
                            --instance-type ${INSTANCE_TYPE} \\
                            --key-name ${KEY_NAME} \\
                            --security-group-ids ${SECURITY_GROUP_ID} \\
                            --subnet-id ${SUBNET_ID} \\
                            --region ${AWS_REGION} \\
                            --query 'Instances[0].InstanceId' \\
                            --output text
                    """, returnStdout: true).trim()

                    env.INSTANCE_ID = instanceInfo
                    echo "EC2 Instance Created: ${env.INSTANCE_ID}"

                    sh """
                        aws ec2 wait instance-running \
                            --instance-ids ${env.INSTANCE_ID} \
                            --region ${AWS_REGION}
                    """

                    def publicIP = sh(script: """
                        aws ec2 describe-instances \
                            --instance-ids ${env.INSTANCE_ID} \
                            --region ${AWS_REGION} \\
                            --query 'Reservations[0].Instances[0].PublicIpAddress' \\
                            --output text
                    """, returnStdout: true).trim()

                    env.PUBLIC_IP = publicIP
                    echo "EC2 Instance Public IP: ${env.PUBLIC_IP}"
                }
            }

            post{
                always{
                    echo "========EC2 Instance========"
                }
                success{
                    echo "========EC2 Instance successfully✅========"
                }
                failure{
                    echo "========EC2 Instance failed❌========"
                }
            }
        }

        stage('Deploy Docker Image on EC2') {
            steps {
                script {
                    // SSH into the newly created EC2 instance and pull/run the Docker image
                    sh """
                        ssh -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem ec2-user@${env.PUBLIC_IP} << EOF
                        # Install Docker
                        sudo yum update -y
                        sudo amazon-linux-extras install docker -y
                        sudo service docker start
                        sudo usermod -aG docker ec2-user
                        newgrp docker

                        # Pull and Run the Docker Image
                        docker pull ${DOCKER_IMAGE}
                        docker run -d -p 8080:8080 ${DOCKER_IMAGE}
                        EOF
                    """
                }
            }
            post{
                always{
                    echo "========Deploy Docker Image========"
                }
                success{
                    echo "========Deploy Docker Image successfully✅========"
                }
                failure{
                    echo "========Deploy Docker Image failed❌========"
                }
            }
        }
    }
    post{
        always{
            echo "========always========"
        }
        success {
            echo "✅ Build, Docker push, and EC2 deployment Successful!"
        }
        failure {
            echo "❌ Build or Deployment Failed"
        }
    }
}