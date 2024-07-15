#!/bin/bash

# Install MySQL server if not installed
sudo apt update
sudo apt install -y mysql-server

# Secure MySQL installation (optional, if not already done)
# sudo mysql_secure_installation

# MySQL commands to create user and grant privileges
MYSQL_COMMANDS=$(cat <<EOF
CREATE USER 'gacerioni'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'gacerioni'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
)

# Execute MySQL commands
sudo mysql -u root -e "$MYSQL_COMMANDS"

# Update MySQL configuration file
sudo sed -i '/\[mysqld\]/a gtid_mode=ON' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/\[mysqld\]/a enforce_gtid_consistency=ON' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/\[mysqld\]/a binlog_rows_query_log_events=ON' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i 's/^bind-address\s*=.*$/bind-address=0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# Restart MySQL service to apply changes and enable it
sudo systemctl restart mysql
sudo systemctl enable mysql

echo "MySQL is configured and running with the specified settings."
