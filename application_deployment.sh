#$/bin/bash

function color_code() {

    NC="\e[1;0m"

    case $1 in
    "green") color="\e[1;32m" ;;
    "red") color="\e[1;31m" ;;
     *) color="\e[1;0m" ;;
    esac

    echo -e "${color} $2 ${NC}"
}

function active_services() {

active_service=$(sudo systemctl is-active "$1")

  if [ "$active_service" = "active" ]
  then
    color_code "green" "$1 service is running......"
  else
    color_code "red" "$1 service is not running......"
    exit 1
  fi
}

function firewall_port_checks() {

firewall_port_check=$(sudo firewall-cmd --list-all --zone=public | grep ports)

if [[ $firewall_port_check == *$1* ]]
then
  color_code "green" "Firewall port $1 configured"
else
  color_code "red" "Firewall port $1 not configured"
fi

}


#######################################
# Check if a given item is present in an output
# Arguments:
#   1 - Output
#   2 - Item
#######################################

function check_item(){
  if [[ $1 = *$2* ]]
  then
    color_code "green" "Item $2 is present on the web page"
  else
    color_code "red" "Item $2 is not present on the web page"
  fi
}

#---------------- DATABASE Configuration ------------------------

# Installation of FIREWALL services
color_code "green" "Firewalld installation in progress...."
sudo yum install -y firewalld
sudo service firewalld start
sudo systemctl enable firewalld

# Firewalld service status check
active_services firewalld

# Installation of MARIADB services
color_code "green" "MariaDB installation in progress...."
sudo yum install -y mariadb-server
sudo service mariadb start
sudo systemctl enable mariadb

# MariaDB service status check
active_services mariadb

# Configure Firewall rules for Database
color_code "green" "# Configure Firewall rules for Database"
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --reload

firewall_port_checks 3306

# Database and USER creation
color_code "green" "Database configuration in-progress"

cat > db-load.sql <<-EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
FLUSH PRIVILEGES;
EOF

tail db-load.sql | sudo mysql

# Table creation and data insertion

cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;
INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");
EOF

tail db-load-script.sql | sudo mysql

product_search=$(sudo mysql -e "use ecomdb; select * from products;")

if [[ $product_search == *Laptop* ]]
then
  color_code "green" "Database successfully configured!!"
else
  color_code "red" "Database not configured!!"
  exit 1
fi

color_code "green" "---------------- Setup Database Server - Finished ------------------"

#---------------- Web Server Configuration ------------------------

# Installation of HTTPD services
color_code "green" "HTTPD installation in progress...."
sudo yum install -y httpd php php-mysql
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload

firewall_port_checks 80

# Replacing .html file with .php
sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf

# Restarting HTTPD services
sudo service httpd start
sudo systemctl enable httpd

# Apache web service status check
active_services httpd

color_code "green" "---------------- Setup Web Server - Finished ------------------"

# Installation of GIT
color_code "green" "Installation of GIT"
sudo yum install -y git
sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/

# Updating index.php file with localhost
color_code "green" "Updating index.php configuration"
sudo sed -i 's/172.20.1.101/localhost/g' /var/www/html/index.php

color_code "green" "------------LAMP stack Installation Completed!!-----------------"

# Test Script
web_page=$(curl http://localhost)

for item in Laptop Drone VR Watch Phone
do
  check_item "$web_page" $item
done
