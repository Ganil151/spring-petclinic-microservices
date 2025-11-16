## Troubleshooting MySQL Privilege Issues

### STEP 1 — Find the correct MySQL binary
Sometimes, especially on systems with multiple MySQL installations, the default `mysql` command might not point to the correct binary. To find the correct MySQL binary, you can use the following command:

```bash
which mysql
```
Or: 

```bash
sudo find / -name mysqld 2>/dev/null
```
It should read out something like `/usr/bin/mysql` or `/usr/local/mysql/bin/mysql`.
---
### STEP 2 — Stop the MySQL service
Before starting MySQL in safe mode, stop the MySQL service:

```bash   
sudo systemctl stop mysql
```
Check Status:
```bash 
sudo systemctl status mysql
```
---
### STEP 3 — Start MySQL in skip-grant-tables mode
Start MySQL without loading the grant tables, which allows you to connect without a password:

```bash 
sudo mysqld --skip-grant-tables --skip-networking --user=mysql &
```
If mysqld is not found, use:
```bash
sudo /usr/bin/mysqld --skip-grant-tables --skip-networking --user=mysql &
```
Replace `/usr/bin/mysqld` with the path you found in STEP 1 if
different.
You should see:
```bash
[1] 12345
```
Where `12345` is the process ID of the MySQL server.
---
### STEP 4 — Log in without password
Now, you can log in to the MySQL server without a password:

```bash
mysql -u root
```
---
### STEP 5 — Reset the MySQL root password
Once logged in, switch to the `mysql` database and update the root password:

```sql
FLUSH PRIVILEGES;

ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'PetclinicRoot123!';

FLUSH PRIVILEGES;
EXIT;
```
Check:
```sql
SELECT user, host, plugin FROM mysql.user;
```
Plugin must be: mysql_native_password
---
### STEP 6 — Kill skip-grants mysqld
Find the process ID of the MySQL server started in STEP 3 and kill it:
```perl
ps aux | grep mysqld
```
Then kill the process using its ID: 
```bash
sudo kill -9 <PID>  
```
---
### STEP 7 — Start MySQL normally
```bash
sudo systemctl start mysql
```
Check Status:
```bash
sudo systemctl status mysql
``` 
---
### STEP 8 — Test login
Now, try logging in with the new root password:

```bash
mysql -u root -p
```
Enter password: PetclinicRoot123!
You should now have access to the MySQL server with the new root password.
---
### STEP 9 — Update Ansible variables  
Update the MySQL root password and petclinic user password in your Ansible variable files to match the new passwords you set:
- In `/etc/ansible/group_vars/mysql.yml`, update:
  ```yaml
  mysql_root_password: "PetclinicRoot123!"
  mysql_petclinic_password: "PetClinic@12345!"
  ```
  mysql_root_password: "petclinic"
  mysql_petclinic_password: "petclinic12"
  ```
- In your Ansible playbooks or roles where the MySQL root password and petclinic user password are referenced, ensure they match the new passwords you set.
- After updating the variables, you can rerun your Ansible playbooks to ensure everything is configured correctly with the new passwords.
- This should resolve any privilege issues related to incorrect passwords in your Ansible configurations.
- Make sure to test the connection to the MySQL server using the updated credentials to confirm that everything is working as expected.
- Remember to keep your passwords secure and avoid hardcoding them in your playbooks. Consider using Ansible Vault for sensitive information.
- With these steps, you should be able to resolve MySQL privilege issues and ensure your Ansible configurations are up to date with the correct passwords.
---

## Uninstall MySQL Server
To uninstall MySQL server from your system, follow the steps below based on your operating system:
o uninstall MySQL completely from AWS Linux 2023, follow these steps: Stop the MySQL service.
```bash
sudo systemctl stop mysqld
```
Remove MySQL packages.

```bash
sudo yum remove mysql mysql-server mysql-client mysql-common -y
```
This command removes the MySQL server, client, and common packages. 
Clean up residual files and directories:
Remove configuration files:
```bash
sudo rm -rf /etc/my.cnf /etc/mysql
```
Remove data directory (optional, but recommended for a clean uninstall):
```bash
sudo rm -rf /var/lib/mysql
```
Caution: This will delete all your MySQL data. Back up any important data before performing this step. Remove log files.
```bash
sudo rm -rf /var/log/mysql*
```
Remove the MySQL user and group (if they exist and are no longer needed):
```bash
sudo userdel mysql
sudo groupdel mysql
```
Clean up package cache.
```bash
sudo yum clean all
```
Verify uninstallation.
You can check if any MySQL-related packages remain by running:
```bash
rpm -qa | grep -i mysql
```
If no output is returned, MySQL has been successfully uninstalled.
