# Fix for MySQL User Verification Error in Jenkinsfile

## Problem
The Ansible command to verify the petclinic user has incorrect quote escaping, causing this error:
```
ansible: error: unrecognized arguments: User, Host FROM mysql.user WHERE User=${MYSQL_PETCLINIC_USER}
```

## Solution

Find this line in your Jenkinsfile (around line 514):

```groovy
ansible mysql -i inventory.ini -m shell \
    -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e \"SELECT User, Host FROM mysql.user WHERE User='${MYSQL_PETCLINIC_USER}';\"" \
```

Replace it with:

```groovy
ansible mysql -i inventory.ini -m shell \
    -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e 'SELECT User FROM mysql.user WHERE User=\"${MYSQL_PETCLINIC_USER}\";'" \
```

## What Changed

1. **Removed escaped quotes** around the SQL query
2. **Used single quotes** for the `-e` parameter
3. **Used escaped double quotes** (`\"`) around the variable in the WHERE clause
4. **Simplified SELECT** to only get User column (we don't need Host for the grep)

## Full Corrected Section

```bash
# Verify petclinic user was created
echo "=== Verifying Petclinic User ==="
ansible mysql -i inventory.ini -m shell \
    -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e 'SELECT User FROM mysql.user WHERE User=\"${MYSQL_PETCLINIC_USER}\";'" \
    | grep "${MYSQL_PETCLINIC_USER}" || {
    echo "ERROR: Petclinic user not found"
    exit 1
}
echo "✓ Petclinic user exists: ${MYSQL_PETCLINIC_USER}"
```

This will properly execute the MySQL query and check if the petclinic user exists.
