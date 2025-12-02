---
- name: Setup MySQL for Spring Petclinic
  hosts: mysql
  become: yes
  vars:
    mysql_root_password: "PetMa3ter$3JH3!"
    petclinic_db: "petclinic"
    petclinic_user: "petclinic"
    petclinic_password: "Wor8erPet@12S45!"
    mysql_port: 3306
  
  tasks:
    - name: Verify MySQL is running
      systemd:
        name: mysqld
        state: started
        enabled: yes

    - name: Wait for MySQL to be fully up
      wait_for:
        port: 3306
        host: 127.0.0.1
        delay: 2
        timeout: 30
        state: started

    - name: Verify MySQL root authentication
      shell: mysql -uroot -p"{{ mysql_root_password }}" -e "SELECT 1;" 2>/dev/null
      register: auth_check
      changed_when: false
      failed_when: auth_check.rc != 0

    - name: Remove anonymous MySQL users
      shell: |
        mysql -uroot -p"{{ mysql_root_password }}" -e "
        DELETE FROM mysql.user WHERE User='';
        FLUSH PRIVILEGES;"
      changed_when: false
      ignore_errors: yes

    - name: Remove test database
      shell: |
        mysql -uroot -p"{{ mysql_root_password }}" -e "DROP DATABASE IF EXISTS test;"
      changed_when: false
      ignore_errors: yes

    - name: Create PetClinic database
      shell: |
        mysql -uroot -p"{{ mysql_root_password }}" -e "CREATE DATABASE IF NOT EXISTS {{ petclinic_db }};"
      changed_when: false

    - name: Create PetClinic user and grant privileges
      shell: |
        mysql -uroot -p"{{ mysql_root_password }}" << EOF
        CREATE USER IF NOT EXISTS '{{ petclinic_user }}'@'%' IDENTIFIED BY '{{ petclinic_password }}';
        GRANT ALL PRIVILEGES ON {{ petclinic_db }}.* TO '{{ petclinic_user }}'@'%';
        FLUSH PRIVILEGES;
        EOF
      changed_when: false

    - name: Verify petclinic user can connect
      shell: |
        mysql -u{{ petclinic_user }} -p"{{ petclinic_password }}" -e "SELECT 1;"
      register: user_auth_check
      changed_when: false
      failed_when: user_auth_check.rc != 0

    - name: Configure MySQL to listen on all interfaces
      lineinfile:
        path: /etc/my.cnf
        regexp: '^bind-address'
        line: 'bind-address = 0.0.0.0'
        state: present
      notify: Restart MySQL

    - name: Display MySQL configuration summary
      debug:
        msg:
          - "======================================"
          - "MySQL Configuration Complete"
          - "======================================"
          - "Database: {{ petclinic_db }}"
          - "User: {{ petclinic_user }}"
          - "Host: {{ ansible_default_ipv4.address }}"
          - "Port: {{ mysql_port }}"
          - "======================================"
          - "Connection string for apps:"
          - "jdbc:mysql://{{ ansible_default_ipv4.address }}:{{ mysql_port }}/{{ petclinic_db }}"
          - "======================================"

  handlers:
    - name: Restart MySQL
      systemd:
        name: mysqld
        state: restarted
