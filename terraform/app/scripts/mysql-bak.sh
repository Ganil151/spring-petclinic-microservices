#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

# Define default values (consider passing these as arguments for more flexibility)
MYSQL_ROOT_PASSWORD_DEFAULT='Mysql$9999!'
MYSQL_PETCLINIC_USER='petclinic'
MYSQL_PETCLINIC_PASSWORD='petclinic' # Consider using a stronger password
MYSQL_DATABASE_NAME='petclinic'
REPO_URL='https://github.com/Ganil151/spring-petclinic-microservices.git'
REPO_DIR='spring-petclinic-microservices'

echo "Starting MySQL setup for Spring PetClinic..."

# --- Hostname Check ---
CURRENT_HOSTNAME=$(hostname)
if [ "$CURRENT_HOSTNAME" != "mysql-server" ]; then
  echo "Current hostname is '$CURRENT_HOSTNAME', changing to 'mysql-server'..."
  sudo hostnamectl set-hostname "mysql-server"
  echo "Hostname changed successfully."
else
  echo "Hostname is already set to 'mysql-server'."
fi

# --- Dependency Check and Installation ---
echo "Checking for and installing dependencies..."
# Check for Java
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
    echo "Java is already installed (version: $JAVA_VERSION)."
else
    echo "Java not found. Installing java-21-amazon-corretto-devel..."
    sudo yum install -y java-21-amazon-corretto-devel
    echo "Java installed."
fi

# Check for wget
if command -v wget &> /dev/null; then
    echo "wget is already installed."
else
    echo "wget not found. Installing wget..."
    sudo yum install -y wget
    echo "wget installed."
fi

# Check for git
if command -v git &> /dev/null; then
    echo "git is already installed."
else
    echo "git not found. Installing git..."
    sudo yum install -y git
    echo "git installed."
fi

# Update system packages
echo "Updating system packages..."
sudo yum update -y


# --- Java Environment Configuration ---
echo "Configuring Java environment variables..."
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
export JAVA_HOME
export PATH="$PATH:$HOME/bin:$JAVA_HOME"
# Add to .bashrc if not already present
if ! grep -q "JAVA_HOME=$JAVA_HOME" ~/.bashrc; then
    echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a ~/.bashrc
    echo "export PATH=$PATH:\$HOME/bin:\$JAVA_HOME" | sudo tee -a ~/.bashrc
    echo "Java environment variables added to ~/.bashrc."
else
    echo "Java environment variables already present in ~/.bashrc."
fi


# --- MySQL Check and Installation ---
if command -v mysql &> /dev/null; then
    MYSQL_VERSION=$(mysql --version)
    echo "MySQL client is already installed ($MYSQL_VERSION)."
    # Check if MySQL server service is active
    if sudo systemctl is-active --quiet mysqld; then
        echo "MySQL server service (mysqld) is already running."
        # This script part might need adjustment if MySQL is already fully configured.
        # For now, we'll assume if the service is running, the initial setup might be complete.
        # You could exit here or proceed with database/user creation if you are sure about the state.
        # exit 1 # Uncomment if you want to stop if MySQL is running
    else
        echo "MySQL server service (mysqld) is installed but not running."
    fi
else
    echo "MySQL client not found. Proceeding with MySQL 8.0 installation..."

    # Check for MySQL repository
    if [ -f "/etc/yum.repos.d/mysql-community.repo" ]; then
        echo "MySQL repository is already configured."
    else
        echo "Installing MySQL 8.0 repository..."
        sudo wget https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
        sudo yum localinstall -y mysql80-community-release-el9-1.noarch.rpm
        sudo rm -f mysql80-community-release-el9-1.noarch.rpm
        echo "MySQL repository installed."
    fi

    # Import MySQL GPG key
    echo "Importing/Refreshing MySQL GPG key..."
    sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
    echo "MySQL GPG key imported."

    # Install MySQL server and client
    echo "Installing MySQL server and client..."
    sudo yum install -y mysql-community-client mysql-community-server
    # Update system packages again after MySQL installation
    sudo yum update -y
    echo "MySQL server and client installed."
fi


# --- Start MySQL Service (if not already running) ---
if sudo systemctl is-active --quiet mysqld; then
    echo "MySQL service (mysqld) is already running."
else
    echo "Starting and enabling MySQL service..."
    sudo systemctl start mysqld
    sudo systemctl enable mysqld
    echo "MySQL service started and enabled."
fi


# --- Secure MySQL Installation (handle potential access denied errors) ---
echo "Checking if MySQL initial setup is needed (looking for temporary password)..."
TEMP_PASSWORD=$(sudo grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}' | tail -n 1)

if [ -z "$TEMP_PASSWORD" ]; then
  echo "Info: No temporary password found in /var/log/mysqld.log."
  echo "      This might mean MySQL is already secured or in an unexpected state."
  echo "      Attempting to connect as root without a password (might work if plugin allows it or if password is blank initially)."
  # Try connecting without a password first
  if mysql -u root --connect-expired-password -e "SELECT 1;" 2>/dev/null; then
      echo "Connected to MySQL as root without a password."
      # If connection is successful, root likely has no password or an expired one allowing connection without it.
      # We need to set the password.
      echo "Setting new root password..."
      mysql -u root --connect-expired-password <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD_DEFAULT';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF
      echo "MySQL root password set, anonymous users removed, test database dropped."
  else
      echo "Failed to connect as root without a password."
      # The state is ambiguous. The root password might be set to something else, or the temporary password was used but the account is locked.
      # The most robust way to handle this outside of this script is often to reset the root password using the --init-file or --skip-grant-tables method,
      # which requires stopping the mysqld service, starting it with the reset option, and then running mysql_secure_installation or similar commands.
      # This script cannot reliably perform that complex reset without user intervention.
      echo "Error: Cannot connect to MySQL as root with temporary password or without a password."
      echo "       The MySQL root account state is unexpected. Manual intervention may be required."
      echo "       You might need to reset the root password using MySQL's password reset procedure."
      echo "       See: https://dev.mysql.com/doc/refman/8.0/en/resetting-permissions.html"
      exit 1
  fi
else
  echo "Temporary password found: $TEMP_PASSWORD (last 4 characters: ${TEMP_PASSWORD: -4})"
  echo "Attempting to secure MySQL installation using the temporary password..."
  if mysql --connect-expired-password -uroot -p"$TEMP_PASSWORD" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD_DEFAULT';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF
  then
      echo "MySQL root password set, anonymous users removed, test database dropped using temporary password."
  else
      echo "Error: Failed to connect using the temporary password. The password might have already been used."
      echo "       Attempting to connect without a password (as sometimes the account becomes accessible this way after failed initial setup attempts)..."
      if mysql -u root --connect-expired-password -e "SELECT 1;" 2>/dev/null; then
          echo "Connected to MySQL as root without a password after temporary password failure."
          echo "Setting new root password..."
          mysql -u root --connect-expired-password <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD_DEFAULT';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF
          echo "MySQL root password set using connection without password after temp password failure."
      else
          echo "Error: Cannot connect as root even after temporary password failure."
          echo "       The MySQL root account state is unexpected. Manual intervention may be required."
          echo "       You might need to reset the root password using MySQL's password reset procedure."
          echo "       See: https://dev.mysql.com/doc/refman/8.0/en/resetting-permissions.html"
          exit 1
      fi
  fi
fi

# Restart MySQL to apply changes (sometimes necessary after initial security setup)
echo "Restarting MySQL service after security changes..."
sudo systemctl restart mysqld
echo "MySQL service restarted."


# --- Create Database and User for Spring PetClinic ---
echo "Creating database '$MYSQL_DATABASE_NAME' and user '$MYSQL_PETCLINIC_USER'..."
# The root password should now be $MYSQL_ROOT_PASSWORD_DEFAULT if the security steps above succeeded
mysql -u root -p"$MYSQL_ROOT_PASSWORD_DEFAULT" <<MYSQL_SETUP_EOF
CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE_NAME;
CREATE USER IF NOT EXISTS '$MYSQL_PETCLINIC_USER'@'%' IDENTIFIED BY '$MYSQL_PETCLINIC_PASSWORD';
CREATE USER IF NOT EXISTS '$MYSQL_PETCLINIC_USER'@'localhost' IDENTIFIED BY '$MYSQL_PETCLINIC_PASSWORD';
GRANT ALL PRIVILEGES ON $MYSQL_DATABASE_NAME.* TO '$MYSQL_PETCLINIC_USER'@'%';
GRANT ALL PRIVILEGES ON $MYSQL_DATABASE_NAME.* TO '$MYSQL_PETCLINIC_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SETUP_EOF

echo "Database '$MYSQL_DATABASE_NAME' and user '$MYSQL_PETCLINIC_USER' created/updated."


# --- Clone Repository and Look for Initialization Scripts ---
echo "Cloning Spring PetClinic repository to look for initialization scripts..."
if [ -d "$REPO_DIR" ]; then
    echo "Warning: Directory $REPO_DIR already exists. Removing..."
    rm -rf "$REPO_DIR"
fi

git clone "$REPO_URL" "$REPO_DIR"

if [ ! -d "$REPO_DIR" ]; then
    echo "Error: Failed to clone the repository '$REPO_URL'."
    exit 1
fi

# Look for common SQL initialization script names
SQL_SCRIPTS=$(find "$REPO_DIR" -type f -name "*.sql" -path "*/db/*" -o -name "*schema*.sql" -o -name "*data*.sql" -o -name "*init*.sql" | head -n 5) # Limit to first 5 found

if [ -n "$SQL_SCRIPTS" ]; then
    echo "Found potential SQL scripts. Attempting to execute them against the '$MYSQL_DATABASE_NAME' database:"
    echo "$SQL_SCRIPTS"
    for script in $SQL_SCRIPTS; do
        echo "Executing $script"
        # Use the application user credentials to execute the script
        if mysql -u "$MYSQL_PETCLINIC_USER" -p"$MYSQL_PETCLINIC_PASSWORD" "$MYSQL_DATABASE_NAME" < "$script"; then
            echo "Successfully executed $script"
        else
            echo "Warning: Failed to execute $script. Check the script content and database state. Exit code: $?"
            # Consider 'continue' if you want to try other scripts despite one failure
            # continue
        fi
    done
else
    echo "No obvious SQL initialization scripts found in the cloned repository ($REPO_DIR)."
    echo "The database '$MYSQL_DATABASE_NAME' and user '$MYSQL_PETCLINIC_USER' have been created."
    echo "You may need to provide or run schema/data scripts manually."
fi

# Cleanup: Remove the cloned repository directory after processing
rm -rf "$REPO_DIR"

echo "MySQL setup for Spring PetClinic completed."
echo "Database: $MYSQL_DATABASE_NAME"
echo "User: $MYSQL_PETCLINIC_USER"
echo "Password: $MYSQL_PETCLINIC_PASSWORD (Please store securely)"
echo "Root Password: $MYSQL_ROOT_PASSWORD_DEFAULT (Please store securely)"
echo "Server IP: $(hostname -I | awk '{print $1}')" # Print primary IP address
