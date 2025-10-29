### Install Jenkins, SonarQube and Docker using Terraform and User Data Script

#### Install SonarQube
(Download Link: https://www.sonarsource.com/products/sonarqube/downloads/success-download-community-edition/)
echo "Installing SonarQube"
sudo apt install -y unzip wget
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.9.0.112764.zip 

#### Jenkins github pipeline 
![alt text](<IMAGES/Screenshot (210).png>)
- Trigger the build when a change is pushed to GitHub
- Add GitHub hook trigger for GITScm polling
- Poll SCM: H/5 * * * * * 

![alt text](<IMAGES/Screenshot (211).png>)

#### Fix Permission Issue in SonarQube
```bash
ubuntu@sonarQ-server:~/sonarqube-25.9.0.112764/bin/linux-x86-64$ ./sonar.sh console
/usr/bin/java
Running SonarQube...
rm: cannot remove './SonarQube.pid': Permission denied
Removed stale pid file: ./SonarQube.pid
./sonar.sh: 151: cannot create ./SonarQube.pid: Permission denied
2025.10.01 19:17:10 INFO  app[][o.s.a.AppFileSystem] Cleaning or creating temp directory /home/ubuntu/sonarqube-25.9.0.112764/temp
2025.10.01 19:17:10 ERROR app[][o.s.application.App] Startup failure
java.lang.IllegalArgumentException: Unable to create shared memory :
        at org.sonar.process.sharedmemoryfile.AllProcessesCommands.<init>(AllProcessesCommands.java:103)
        at org.sonar.application.AppFileSystem.reset(AppFileSystem.java:63)
        at org.sonar.application.App.start(App.java:53)
        at org.sonar.application.App.main(App.java:81)
Caused by: java.io.FileNotFoundException: /home/ubuntu/sonarqube-25.9.0.112764/temp/sharedmemory (Permission denied)
        at java.base/java.io.RandomAccessFile.open0(Native Method)
        at java.base/java.io.RandomAccessFile.open(RandomAccessFile.java:356)
        at java.base/java.io.RandomAccessFile.<init>(RandomAccessFile.java:273)
        at java.base/java.io.RandomAccessFile.<init>(RandomAccessFile.java:223)
        at org.sonar.process.sharedmemoryfile.AllProcessesCommands.<init>(AllProcessesCommands.java:100)
        ... 3 common frames omitted
## Fix Permission Issue
ls -ld /home/ubuntu/sonarqube-25.9.0.112764/temp
sudo chown -R ubuntu:ubuntu /home/ubuntu/sonarqube-25.9.0.112764/temp

```

#### SonarQube Bash Script to Start SonarQube
```bash
#!/bin/bash

set -e

# Change Host Name
echo "Changing Host Name"
sudo hostnamectl set-hostname "sonarQ-server"

# Install dependencies and update system
echo "Installing dependencies and updating system"
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y openjdk-21-jdk unzip git

# Create dedicated user for SonarQube
echo "Creating dedicated sonarqube user"
sudo useradd --system --no-create-home sonarqube || true

# Download and extract SonarQube
echo "Downloading and extracting SonarQube"
SONAR_VERSION="25.9.0.112764"
SONAR_DIR="/opt/sonarqube-${SONAR_VERSION}"
wget "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip"
sudo unzip "sonarqube-${SONAR_VERSION}.zip" -d /opt/
sudo rm "sonarqube-${SONAR_VERSION}.zip"

# Configure Java for SonarQube service
echo "Configuring Java for SonarQube service"
JAVA_HOME=$(update-alternatives --query java | grep '^Value:' | awk '{print $2}' | sed 's/\/bin\/java//')
if [ -z "$JAVA_HOME" ]; then
    echo "ERROR: Could not determine JAVA_HOME path."
    exit 1
fi
echo "JAVA_HOME found: $JAVA_HOME"

# Configure sonar.sh to use the correct Java path
sudo sed -i 's|#RUN_AS_USER=sonarqube|RUN_AS_USER=sonarqube|g' "${SONAR_DIR}/bin/linux-x86-64/sonar.sh"
sudo tee "${SONAR_DIR}/conf/sonar.properties" > /dev/null <<EOL
sonar.jdbc.url=jdbc:h2:file:./data/sonarqube;DB_CLOSE_DELAY=-1;AUTO_SERVER=true
sonar.web.javaAdditionalOpts=-Djava.security.egd=file:/dev/./urandom
sonar.search.javaAdditionalOpts=-Djava.security.egd=file:/dev/./urandom
# For better performance on larger instances, set the Elasticsearch heap size.
# sonar.search.javaOpts=-Xms512m -Xmx512m
# Set the Java home explicitly for SonarQube's wrapper.
wrapper.java.command=${JAVA_HOME}/bin/java
EOL

# Adjust permissions for the SonarQube directory
echo "Setting permissions for SonarQube directory"
sudo chown -R sonarqube:sonarqube "${SONAR_DIR}"
sudo chmod -R 755 "${SONAR_DIR}"
sudo chmod -R 775 "${SONAR_DIR}/temp"
sudo chmod +x "${SONAR_DIR}/bin/linux-x86-64/sonar.sh"

# Increase /tmp size and make persistent
echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
sudo mount -o remount /tmp

# Reload systemd and start the SonarQube service
echo "Reloading systemd and starting SonarQube service"
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

echo "Script execution complete. SonarQube should be running as a service."
``` 

The logs indicate that SonarQube is failing to start due to a database migration error. Specifically, the issue arises because SonarQube is configured to use the H2 database (jdbc:h2:file:./data/sonarqube), which is intended only for evaluation purposes and not suitable for production use. The error occurs during the execution of the first database migration step (Create initial schema) because the H2 database does not fully support the SQL syntax required by SonarQube.

To resolve this issue, you need to configure SonarQube to use a production-grade database such as MySQL or MariaDB instead of H2. Below are the steps to switch from H2 to MySQL or MariaDB:

Step 1: Install MySQL or MariaDB
If MySQL or MariaDB is not already installed on your system, follow these steps:

Install MySQL
```bash
sudo apt update
sudo apt install mysql-server -y
```
Install MariaDB
```bash
sudo apt update
sudo apt install mariadb-server -y
Step 2: Secure the Database Installation
Run the security script to set a root password and secure the database installation.
```
For MySQL
```bash
sudo mysql_secure_installation
```
For MariaDB
```bash
sudo mysql_secure_installation
```
Step 3: Create a Database and User for SonarQube
Log in to the MySQL or MariaDB server and create a dedicated database and user for SonarQube.

```bash
sudo mysql -u root -p
```
For MariaDB
```bash
sudo mariadb -u root -p
```
sudo mysql_secure_installation
Step 3: Create a Database and User for SonarQube
Log in to the MySQL or MariaDB server and create a dedicated database and user for SonarQube.

Login to MySQL/MariaDB
```bash
sudo mysql -u root -p
```
For MariaDB
```bash
sudo mariadb -u root -p
```
```bash
sudo mysql_secure_installation
```
Step 3: Create a Database and User for SonarQube
Log in to the MySQL or MariaDB server and create a dedicated database and user for SonarQube.   
Run the following SQL commands:

```bash
CREATE DATABASE sonarqube CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'sonarqube'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON sonarqube.* TO 'sonarqube'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```
Replace your_password with a strong password.

- Step 4: Update SonarQube Configuration
Edit the SonarQube configuration file to use MySQL or MariaDB instead of H2.

Locate the Configuration File
The configuration file is typically located at:

```bash
/opt/sonarqube-25.9.0.112764/conf/sonar.properties
Update the Database Connection Settings
Open the file in a text editor:
```

```bash
sudo nano /opt/sonarqube-25.9.0.112764/conf/sonar.properties
Comment out the H2 database settings and add the MySQL/MariaDB configuration:
properties
```


# Comment out H2 settings
```bash
#sonar.jdbc.url=jdbc:h2:tcp://localhost/sonarqube
#sonar.jdbc.username=sonarqube
#sonar.jdbc.password=sonarqube

# Add MySQL/MariaDB settings
sonar.jdbc.url=jdbc:mysql://localhost:3306/sonarqube?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=UTC
sonar.jdbc.username=sonarqube
sonar.jdbc.password=your_password
```
Replace your_password with the password you set earlier.

Step 5: Add MySQL/MariaDB JDBC Driver
SonarQube requires the MySQL/MariaDB JDBC driver to connect to the database.

Additional Notes
Database Compatibility
Ensure that the MySQL/MariaDB version is compatible with SonarQube. For example, SonarQube 25.9.0 supports MySQL 8.x and MariaDB 10.3+.
Java Version
Ensure that the Java version installed on your system is compatible with both SonarQube and the MySQL/MariaDB JDBC driver.
Memory Allocation
If you encounter memory-related issues, increase the heap size for Elasticsearch and SonarQube by modifying the jvm.options file.
Port Conflicts
Ensure that the default MySQL/MariaDB port (3306) is not in use by another service.
Conclusion
By switching from H2 to MySQL or MariaDB, you eliminate the limitations of the H2 database and ensure that SonarQube runs in a production-ready environment. Follow the steps above carefully, and verify the logs to confirm successful startup. If any issues persist, provide the relevant log entries for further assistance.

