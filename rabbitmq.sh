#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/${0}.log"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $user_id -ne 0 ]; then
    echo "Please run this script with sudo access.."
    exit 1
fi

mkdir -p $logs_folder

timestamp(){
    date "+%F %T" 
}

validate(){
    if [ $1 -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${2}..${R}FAILED${N}" | tee -a $logs_file
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${2}..${G}SUCCESS${N}" | tee -a $logs_file
    fi
}

echo "$(timestamp) [INFO] ==== Script started Execution, Setting up the RabbitMQ Service =====" | tee -a $logs_file

cp repos/rabbitmq.repo /etc/yum.repos.d/rabbitmq.repo
validate $? "Adding RabbitMQ repo"

dnf install erlang rabbitmq-server -y &>> $logs_file
validate $? "Installing RabbitMQ server"

systemctl enable --now rabbitmq-server &>> $logs_file
validate $? "Enabling and Starting RabbitMQ Server"

rabbitmqctl add_user roboshop roboshop123 &>> $logs_file 
validate $? "Creating RabbitMQ user for Roboshop"

rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" &>> $logs_file
validate $? "Setting permissions for RabbitMQ user for Roboshop"

systemctl status rabbitmq-server | tee -a $logs_file
ss -lntp | grep 5672 | tee -a $logs_file
rabbitmqctl list_users | tee -a $logs_file

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds"
echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a $logs_file

