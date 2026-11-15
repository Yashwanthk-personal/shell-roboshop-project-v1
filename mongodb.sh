#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/${0}.log"
repo_folder="$(PWD)/repo"
service_folder="$(PWD)/service"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $user_id -ne 0 ]; then 
    echo "Please run this script with Root access or with Sudo"
    exit 1
fi

mkdir -p $logs_folder

echo "Script Started Execution at $(date +"%F %T")" &>> $logs_file

validate() {
 
    if [ $1 -ne 0 ];
        echo -e "${2}.... ${R}FAILED${N}" | tee -a $logs_file
        exit 1
    else
        echo -e "${2}.... ${G}SUCCESS${N}" | tee -a $logs_file
    fi
}

cp /repo/mongo.repo /etc/yum.repos.d/mongo.repo
validate $? "Adding mongo repo"

dnf install mongodb-org -y &>> $logs_file
validate $? "Installing mongoDB"

systemctl enable mongod &>> $logs_file
systemctl start mongod &>> $logs_file
validate $? "Enable and Start Mongodb"

set -i 's/127.0.0.0/0.0.0.0' /etc/mongod.conf
validate $? "Updating Remote connections to Mongod"

systemctl restart mongod &>> $logs_file
validate $? "Restarting Mongod"
