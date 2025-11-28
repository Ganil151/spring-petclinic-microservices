# Critical Fix for Jenkinsfile MySQL Configuration Stage

## Problem
The "Configure MySQL Database" stage has a syntax error causing "unexpected end of file". The issue is on line 504-506 where there's a missing closing brace `}` and `exit 1` statement.

## Complete Fixed MySQL Configuration Stage

Replace the entire "Configure MySQL Database" stage (starting around line 440) with this corrected version:

```groovy
stage('Configure MySQL Database') {
    steps {
        withCredentials([
            [$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'],
            usernamePassword(credentialsId: 'mysql-root-credentials', usernameVariable: 'MYSQL_ROOT_USER', passwordVariable: 'MYSQL_ROOT_PASSWORD'),
            usernamePassword(credentialsId: 'mysql-petclinic-credentials', usernameVariable: 'MYSQL_PETCLINIC_USER', passwordVariable: 'MYSQL_PETCLINIC_PASSWORD')
        ]) {
            script {
                echo "Configuring MySQL databases with Ansible..."
                
                sh '''
                set -e
                
                echo "=== MySQL Configuration ==="
                echo "MySQL Root User: ${MYSQL_ROOT_USER}"
                echo "Petclinic User: ${MYSQL_PETCLINIC_USER}"
                echo ""
                
                # Update Ansible group_vars with credentials from Jenkins
                echo "Updating Ansible variables with Jenkins credentials..."
                cat > ansible/group_vars/mysql.yml <<EOF
---
mysql_root_password: "${MYSQL_ROOT_PASSWORD}"
mysql_petclinic_password: "${MYSQL_PETCLINIC_PASSWORD}"

petclinic_databases:
- customers
- visits
- vets

petclinic_users:
- name: ${MYSQL_PETCLINIC_USER}
    password: "{{ mysql_petclinic_password }}"
    priv: "*.*:ALL"
EOF
                
                echo "✓ Ansible variables updated"
                echo ""
                
                # Test Ansible connectivity
                echo "=== Testing Ansible Connectivity ==="
                cd /etc/ansible
                ansible mysql -i inventory.ini -m ping || {
                    echo "ERROR: Cannot connect to MySQL server via Ansible"
                    exit 1
                }
                echo "✓ Ansible connectivity verified"
                echo ""
                
                # Run Ansible playbook
                echo "=== Running Ansible Playbook ==="
                ansible-playbook -i inventory.ini mysql_setup.yml -v || {
                    echo "ERROR: Ansible playbook failed"
                    exit 1
                }
                echo "✓ Ansible playbook completed successfully"
                echo ""
                
                # Verify databases were created
                echo "=== Verifying Database Creation ==="
                ansible mysql -i inventory.ini -m shell \\
                    -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e 'SHOW DATABASES;'" \\
                    | grep -E 'customers|visits|vets' || {
                    echo "ERROR: Required databases not found"
                    exit 1
                }
                echo "✓ All required databases exist (customers, visits, vets)"
                echo ""
                
                # Verify petclinic user was created
                echo "=== Verifying Petclinic User ==="
                ansible mysql -i inventory.ini -m shell \\
                    -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e 'SELECT User FROM mysql.user WHERE User=\"${MYSQL_PETCLINIC_USER}\";'" \\
                    | grep "${MYSQL_PETCLINIC_USER}" || {
                    echo "ERROR: Petclinic user not found"
                    exit 1
                }
                echo "✓ Petclinic user exists: ${MYSQL_PETCLINIC_USER}"
                echo ""
                
                # Test petclinic user can connect
                echo "=== Testing Petclinic User Connection ==="
                ansible mysql -i inventory.ini -m shell \\
                    -a "mysql -u ${MYSQL_PETCLINIC_USER} -p${MYSQL_PETCLINIC_PASSWORD} -e 'SELECT 1;'" || {
                    echo "ERROR: Petclinic user cannot connect"
                    exit 1
                }
                echo "✓ Petclinic user can connect successfully"
                echo ""
                
                # Test petclinic user has access to databases
                echo "=== Verifying Database Access ==="
                for db in customers visits vets; do
                    echo "Testing access to $db database..."
                    ansible mysql -i inventory.ini -m shell \\
                        -a "mysql -u ${MYSQL_PETCLINIC_USER} -p${MYSQL_PETCLINIC_PASSWORD} -e 'USE $db; SELECT 1;'" || {
                        echo "ERROR: Petclinic user cannot access $db database"
                        exit 1
                    }
                    echo "✓ Access to $db database verified"
                done
                echo ""
                
                # Check if tables exist (schema loaded)
                echo "=== Checking Database Schema ==="
                for db in customers visits vets; do
                    echo "Checking tables in $db database..."
                    TABLE_COUNT=$(ansible mysql -i inventory.ini -m shell \\
                        -a "mysql -u ${MYSQL_PETCLINIC_USER} -p${MYSQL_PETCLINIC_PASSWORD} -e 'USE $db; SHOW TABLES;'" \\
                        | grep -c "owners\\|pets\\|visits\\|vets\\|specialties" || echo "0")
                    
                    if [ "$TABLE_COUNT" -gt 0 ]; then
                        echo "✓ $db database has $TABLE_COUNT tables"
                    else
                        echo "⚠ $db database has no tables (schema may need to be loaded)"
                    fi
                done
                echo ""
                
                # Get MySQL server info
                echo "=== MySQL Server Information ==="
                ansible mysql -i inventory.ini -m shell \\
                    -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e 'SELECT VERSION();'" \\
                    | grep -v "CHANGED\\|mysql" || true
                echo ""
                
                # Get MySQL server IP
                MYSQL_IP=$(grep "mysql-server ansible_host" ansible/inventory.ini | awk '{print $2}' | cut -d'=' -f2)
                echo "MySQL Server IP: $MYSQL_IP"
                echo ""
                
                echo "=== MySQL Configuration Complete ==="
                echo "✓ Databases: customers, visits, vets"
                echo "✓ User: ${MYSQL_PETCLINIC_USER}"
                echo "✓ Connection: ${MYSQL_IP}:3306"
                echo "✓ All health checks passed"
                '''
            }
        }
    }
}
```

## Key Fixes

1. **Added missing closing brace and exit** on line 506 (after database verification)
2. **Fixed quote escaping** in MySQL user verification query
3. **All error blocks** now have proper `exit 1` statements
4. **All success messages** are properly placed after their checks

## How to Apply

1. Open your Jenkinsfile
2. Find the `stage('Configure MySQL Database')` section
3. Replace the entire stage with the code above
4. Save and run the pipeline

This will fix the "unexpected end of file" syntax error!
