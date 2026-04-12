#!/bin/bash
component=$1
env=$2
app_version=$3

dnf install ansible -y
cd /home/ec2-user
git clone https://github.com/sowjanya88s/ansible-roboshop-roles-tf.git
git pull
cd ansible-roboshop-roles-tf
ansible-playbook -e component=$component env=$environment app_version=$app_version roboshop.yaml