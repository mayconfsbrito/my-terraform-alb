#! /bin/bash
sudo yum install httpd24 amazon-linux-extras -y
sudo cp /var/www/noindex/index.html /var/www/html/
sudo service httpd start
sudo chkconfig httpd on