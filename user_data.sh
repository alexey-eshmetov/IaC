#!/bin/bash
sudo apt -y update
sudo apt -y install nginx
myip=`dig +short myip.opendns.com @resolver1.opendns.com`
sudo echo "<h2>Hello from '$myip'!</h2><br>Builded by Alexey Eshmetov via Terraform :) <img src="https://s3.us-east-2.amazonaws.com/devops.l2-s3bucket-prod-alexey-eshmetov/hello.jpg">" > /var/www/html/index.nginx-debian.html
sudo systemctl start nginx
sudo systemctl enable nginx
